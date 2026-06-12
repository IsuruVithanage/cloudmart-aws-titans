# ============================================================
# All Helm-based Kubernetes Add-ons
# Managed via Terraform for full automation and reproducibility
# ============================================================

# Wait for EKS cluster to be ready
resource "null_resource" "wait_for_eks" {
  provisioner "local-exec" {
    command = "echo 'Waiting for EKS cluster...' && sleep 90"
  }
  depends_on = [module.eks]
}

# ============================================================
# 1. AWS Load Balancer Controller
# ============================================================

# ServiceAccount
resource "kubernetes_service_account" "aws_load_balancer_controller" {
  metadata {
    name      = "aws-load-balancer-controller"
    namespace = "kube-system"
    annotations = {
      "eks.amazonaws.com/role-arn" = module.iam_eks_role_alb_controller.iam_role_arn
    }
  }
  depends_on = [
    null_resource.wait_for_eks,
    module.iam_eks_role_alb_controller
  ]
}

# Helm Release
resource "helm_release" "aws_load_balancer_controller" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  namespace  = "kube-system"
  version    = "1.8.1"

  set { name = "clusterName"; value = module.eks.cluster_name }
  set { name = "serviceAccount.create"; value = "false" }
  set { name = "serviceAccount.name"; value = "aws-load-balancer-controller" }
  set { name = "region"; value = "ap-south-1" }
  set { name = "vpcId"; value = module.networking.vpc_id }

  depends_on = [
    kubernetes_service_account.aws_load_balancer_controller,
    null_resource.wait_for_eks
  ]
}

# ============================================================
# 2. External Secrets Operator
# ============================================================

# ServiceAccount
resource "kubernetes_service_account" "external_secrets_sa" {
  metadata {
    name      = "external-secrets-sa"
    namespace = "cloudmart-prod"
    annotations = {
      "eks.amazonaws.com/role-arn" = module.iam_eks_role_external_secrets.iam_role_arn
    }
  }
  depends_on = [
    null_resource.wait_for_eks,
    module.iam_eks_role_external_secrets
  ]
}

# Helm Release
resource "helm_release" "external_secrets" {
  name       = "external-secrets"
  repository = "https://charts.external-secrets.io"
  chart      = "external-secrets"
  namespace  = "external-secrets"
  create_namespace = true
  version    = "0.15.0"

  set { name = "installCRDs"; value = "true" }
  set { name = "serviceAccount.create"; value = "false" }
  set { name = "serviceAccount.name"; value = "external-secrets-sa" }

  depends_on = [
    kubernetes_service_account.external_secrets_sa,
    null_resource.wait_for_eks
  ]
}

# ============================================================
# 3. KEDA (Kubernetes Event Driven Autoscaling)
# ============================================================

# ServiceAccount
resource "kubernetes_service_account" "keda_operator" {
  metadata {
    name      = "keda-operator"
    namespace = "cloudmart-prod"
    annotations = {
      "eks.amazonaws.com/role-arn" = module.iam_eks_role_keda.iam_role_arn
    }
  }
  depends_on = [
    null_resource.wait_for_eks,
    module.iam_eks_role_keda
  ]
}

resource "helm_release" "keda" {
  name       = "keda"
  repository = "https://kedacore.github.io/charts"
  chart      = "keda"
  namespace  = "keda"
  create_namespace = true
  version    = "2.15.0"

  set { name = "serviceAccount.create"; value = "false" }
  set { name = "serviceAccount.name"; value = "keda-operator" }

  depends_on = [
    kubernetes_service_account.keda_operator,
    null_resource.wait_for_eks
  ]
}