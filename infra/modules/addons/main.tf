# ================================================
# Contains all Helm + Kubernetes resources
# ================================================

# ================================================
# 0. Namespaces
# ================================================
resource "kubernetes_namespace" "cloudmart_prod" {
  metadata {
    name = "cloudmart-prod"
    labels = {
      "kubernetes.io/metadata.name" = "cloudmart-prod"
      environment                   = "production"
      project                       = "cloudmart"
    }
  }
}

resource "kubernetes_namespace" "cloudmart_staging" {
  metadata {
    name = "cloudmart-staging"
    labels = {
      "kubernetes.io/metadata.name" = "cloudmart-staging"
      environment                   = "staging"
      project                       = "cloudmart"
    }
  }
}

# ================================================
# 1. AWS Load Balancer Controller
# ================================================
resource "kubernetes_service_account" "aws_load_balancer_controller" {
  metadata {
    name      = "aws-load-balancer-controller"
    namespace = "kube-system"
    annotations = {
      "eks.amazonaws.com/role-arn" = var.alb_controller_role_arn
    }
  }
}

resource "helm_release" "aws_load_balancer_controller" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  namespace  = "kube-system"
  version    = "1.8.1"
  cleanup_on_fail = true
  replace         = true

  set {
    name  = "clusterName"
    value = var.cluster_name
  }

  set {
    name  = "serviceAccount.create"
    value = "false"
  }

  set {
    name  = "serviceAccount.name"
    value = "aws-load-balancer-controller"
  }

  set {
    name  = "region"
    value = "ap-south-1"
  }

  set {
    name  = "vpcId"
    value = var.vpc_id
  }

  set {
    name  = "replicaCount"
    value = "1"
  }

  depends_on = [kubernetes_service_account.aws_load_balancer_controller]
}

# ================================================
# 2. External Secrets Operator
# ================================================
resource "helm_release" "external_secrets" {
  name             = "external-secrets"
  repository       = "https://charts.external-secrets.io"
  chart            = "external-secrets"
  namespace        = "external-secrets"
  create_namespace = true
  version          = "0.15.0"
  cleanup_on_fail  = true
  replace          = true
  timeout          = 900

  set {
    name  = "installCRDs"
    value = "true"
  }

  set {
    name  = "serviceAccount.create"
    value = "false"
  }

  set {
    name  = "webhook.create"
    value = "false"
  }

  set {
    name  = "webhook.certManager.enabled"
    value = "false"
  }

  set {
    name  = "certController.create"
    value = "false"
  }

  depends_on = [ helm_release.aws_load_balancer_controller ]
}


resource "kubernetes_service_account" "external_secrets_sa" {
  metadata {
    name      = "external-secrets-sa"
    namespace = kubernetes_namespace.cloudmart_prod.metadata[0].name
    annotations = {
      "eks.amazonaws.com/role-arn" = var.external_secrets_role_arn
    }
  }

  depends_on = [
    kubernetes_namespace.cloudmart_prod,
    helm_release.external_secrets,
  ]
}

# ================================================
# SecretStore + ExternalSecret
# ================================================
resource "kubectl_manifest" "aws_secrets_manager_store" {
  yaml_body = yamlencode({
    apiVersion = "external-secrets.io/v1beta1"
    kind       = "SecretStore"
    metadata = {
      name      = "aws-secrets-manager"
      namespace = kubernetes_namespace.cloudmart_prod.metadata[0].name
    }
    spec = {
      provider = {
        aws = {
          service = "SecretsManager"
          region  = "ap-south-1"
          auth = {
            jwt = {
              serviceAccountRef = {
                name = kubernetes_service_account.external_secrets_sa.metadata[0].name
              }
            }
          }
        }
      }
    }
  })

  depends_on = [
    helm_release.external_secrets,
    kubernetes_service_account.external_secrets_sa
  ]
}

resource "kubectl_manifest" "cloudmart_db_secret" {
  yaml_body = yamlencode({
    apiVersion = "external-secrets.io/v1beta1"
    kind       = "ExternalSecret"
    metadata = {
      name      = "cloudmart-db-secret"
      namespace = kubernetes_namespace.cloudmart_prod.metadata[0].name
    }
    spec = {
      refreshInterval = "1h"
      secretStoreRef = {
        name = "aws-secrets-manager"
        kind = "SecretStore"
      }
      target = {
        name           = "cloudmart-secrets"
        creationPolicy = "Owner"
      }
      data = [
        {
          secretKey = "DB_PASSWORD"
          remoteRef = {
            key      = var.db_secret_arn
            property = "DB_PASSWORD"
          }
        },
        {
          secretKey = "DB_USER"
          remoteRef = {
            key      = var.db_secret_arn
            property = "DB_USER"
          }
        },
        {
          secretKey = "DB_NAME"
          remoteRef = {
            key      = var.db_secret_arn
            property = "DB_NAME"
          }
        },
        {
          secretKey = "JWT_SECRET"
          remoteRef = {
            key      = var.db_secret_arn
            property = "DB_PASSWORD"
          }
        }
      ]
    }
  })

  depends_on = [kubectl_manifest.aws_secrets_manager_store]
}

# ================================================
# 3. KEDA
# ================================================
resource "helm_release" "keda" {
  name             = "keda"
  repository       = "https://kedacore.github.io/charts"
  chart            = "keda"
  namespace        = "keda"
  create_namespace = true
  version          = "2.15.0"
  cleanup_on_fail = true
  replace         = true

  set {
    name  = "serviceAccount.create"
    value = "false"
  }

  set {
    name  = "operator.replicaCount"
    value = "1"
  }

  set {
    name  = "crds.install"
    value = "true"
  }

  depends_on = [ helm_release.aws_load_balancer_controller ]
}


resource "kubernetes_service_account" "keda_operator" {
  metadata {
    name      = "keda-operator"
    namespace = kubernetes_namespace.cloudmart_prod.metadata[0].name
    annotations = {
      "eks.amazonaws.com/role-arn" = var.keda_role_arn
    }
  }

  depends_on = [
    kubernetes_namespace.cloudmart_prod,
    helm_release.keda,
  ]
}

# ================================================
# 4. Kyverno
# ================================================
resource "helm_release" "kyverno" {
  name             = "kyverno"
  repository       = "https://kyverno.github.io/kyverno/"
  chart            = "kyverno"
  namespace        = "kyverno"
  create_namespace = true
  version          = "3.1.4"
  cleanup_on_fail  = true
  replace          = true
  timeout          = 900

  set {
    name  = "admissionController.replicas"
    value = "1"
  }

  set {
    name  = "backgroundController.replicas"
    value = "1"
  }
  
  set {
    name  = "cleanupController.replicas"
    value = "1"
  }

  set {
    name  = "reportsController.replicas"
    value = "1"
  }
}
# ================================================
# Automatically adjusts the node count (min=2, max=3) based on pod scheduling pressure.
# Uses IRSA for AWS API access and autodiscovery mode for the EKS managed node group.
# ================================================
resource "kubernetes_service_account" "cluster_autoscaler" {
  metadata {
    name      = "cluster-autoscaler"
    namespace = "kube-system"
    annotations = {
      "eks.amazonaws.com/role-arn" = var.cluster_autoscaler_role_arn
    }
    labels = {
      "k8s-addon" = "cluster-autoscaler.addons.k8s.io"
      "k8s-app"   = "cluster-autoscaler"
    }
  }
  depends_on = [helm_release.aws_load_balancer_controller]
}

resource "helm_release" "cluster_autoscaler" {
  name       = "cluster-autoscaler"
  repository = "https://kubernetes.github.io/autoscaler"
  chart      = "cluster-autoscaler"
  namespace  = "kube-system"
  version    = "9.37.0"
  cleanup_on_fail = true
  replace         = true

  # Use existing service account (annotated with IRSA role above)
  set {
    name  = "rbac.serviceAccount.create"
    value = "false"
  }
  set {
    name  = "rbac.serviceAccount.name"
    value = "cluster-autoscaler"
  }

  # Autodiscovery: finds the ASG by the EKS cluster tag
  set {
    name  = "autoDiscovery.clusterName"
    value = var.cluster_name
  }
  set {
    name  = "awsRegion"
    value = "ap-south-1"
  }

  # Allow scale-down of nodes running system pods (excluding kube-system DaemonSets)
  set {
    name  = "extraArgs.skip-nodes-with-system-pods"
    value = "false"
  }

  # Balance replicas evenly across node groups
  set {
    name  = "extraArgs.balance-similar-node-groups"
    value = "true"
  }

  # Scale down after 2 minutes of a node being underutilised (default is 10 min — shortened for demo)
  set {
    name  = "extraArgs.scale-down-delay-after-add"
    value = "2m"
  }

  # Emit cluster-autoscaler events to CloudWatch (picked up by Container Insights)
  set {
    name  = "extraArgs.emit-per-nodegroup-metrics"
    value = "true"
  }

  depends_on = [
    kubernetes_service_account.cluster_autoscaler,
    helm_release.aws_load_balancer_controller,
  ]
}
