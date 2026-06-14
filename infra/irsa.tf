data "aws_caller_identity" "current" {}

# 1. Product Service Role (DynamoDB + X-Ray)
module "iam_eks_role_product" {
  source    = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version   = "~> 5.39"
  role_name = "cloudmart-product-service-role"
  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["cloudmart-prod:product-service-sa"]
    }
  }
  role_policy_arns = { policy = aws_iam_policy.product_service.arn }
}
resource "aws_iam_policy" "product_service" {
  name = "cloudmart-product-policy"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect   = "Allow",
        Action   = ["dynamodb:*"],
        Resource = "arn:aws:dynamodb:${var.region}:${data.aws_caller_identity.current.account_id}:table/cloudmart-products"
      },
      {
        Effect   = "Allow",
        Action   = [
          "xray:PutTraceSegments",
          "xray:PutTelemetryRecords"
        ],
        Resource = "*"
      }
    ]
  })
}

# 2. Order Service Role (SQS + CloudWatch Metrics + X-Ray)
module "iam_eks_role_order" {
  source    = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version   = "~> 5.39"
  role_name = "cloudmart-order-service-role"
  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["cloudmart-prod:order-service-sa"]
    }
  }
  role_policy_arns = { policy = aws_iam_policy.order_service.arn }
}
resource "aws_iam_policy" "order_service" {
  name = "cloudmart-order-policy"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect   = "Allow",
        Action   = ["sqs:SendMessage"],
        Resource = "arn:aws:sqs:${var.region}:${data.aws_caller_identity.current.account_id}:cloudmart-orders"
      },
      {
        Effect   = "Allow",
        Action   = ["cloudwatch:PutMetricData"],
        Resource = "*"
      },
      {
        Effect   = "Allow",
        Action   = [
          "xray:PutTraceSegments",
          "xray:PutTelemetryRecords"
        ],
        Resource = "*"
      }
    ]
  })
}

# 3. User Service Role (Secrets Manager access)
module "iam_eks_role_user" {
  source    = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version   = "~> 5.39"
  role_name = "cloudmart-user-service-role"
  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["cloudmart-prod:user-service-sa"]
    }
  }
  role_policy_arns = { policy = aws_iam_policy.user_service.arn }
}
resource "aws_iam_policy" "user_service" {
  name = "cloudmart-user-policy"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
        {
            Effect = "Allow",
            Action = ["secretsmanager:GetSecretValue"],
            Resource = "${module.data_services.secret_arn}*"
        }
    ]
  })
}

# 4. Notification Service Role (SQS Receive + SES Send access)
module "iam_eks_role_notification" {
  source    = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version   = "~> 5.39"
  role_name = "cloudmart-notification-service-role"
  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["cloudmart-prod:notification-service-sa"]
    }
  }
  role_policy_arns = { policy = aws_iam_policy.notification_service.arn }
}
resource "aws_iam_policy" "notification_service" {
  name = "cloudmart-notification-policy"
  policy = jsonencode({
    Version = "2012-10-17", Statement = [
      {
          Effect = "Allow",
          Action = ["sqs:ReceiveMessage", "sqs:DeleteMessage", "sqs:GetQueueAttributes"],
          Resource = "arn:aws:sqs:${var.region}:${data.aws_caller_identity.current.account_id}:cloudmart-orders"
      },
      {
          Effect = "Allow",
          Action = ["ses:SendEmail"],
          Resource = [
            for email in toset(concat(
              [var.ses_email],
              tolist(var.test_recipient_emails)
            )) :
            "arn:aws:ses:${var.region}:${data.aws_caller_identity.current.account_id}:identity/${email}"
          ]
      }
    ]
  })
}

# 5. IAM Role for AWS Load Balancer Controller (Official Policy)
module "iam_eks_role_alb_controller" {
  source    = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version   = "~> 5.39"
  role_name = "AmazonEKSLoadBalancerControllerRole"
  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:aws-load-balancer-controller"]
    }
  }
  role_policy_arns = {
    alb_controller = aws_iam_policy.alb_controller.arn
  }
}

# Official policy downloaded from upstream
resource "aws_iam_policy" "alb_controller" {
  name        = "AWSLoadBalancerControllerIAMPolicy"
  description = "IAM policy for AWS Load Balancer Controller (official)"
  policy = file("${path.module}/policies/aws-load-balancer-controller-policy.json")
}

# 6. IAM Role for External Secrets Operator
module "iam_eks_role_external_secrets" {
  source    = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version   = "~> 5.39"
  role_name = "cloudmart-external-secrets-role"
  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["cloudmart-prod:external-secrets-sa"]
    }
  }

  role_policy_arns = { secretsmanager = "arn:aws:iam::aws:policy/SecretsManagerReadWrite" }
}

# 7. IAM Role for KEDA (for SQS scaling)
module "iam_eks_role_keda" {
  source    = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version   = "~> 5.39"
  role_name = "cloudmart-keda-role"
  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["cloudmart-prod:keda-operator"]
    }
  }
  role_policy_arns = { sqs = "arn:aws:iam::aws:policy/AmazonSQSFullAccess" }
}