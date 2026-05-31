# ==================== BASIC RESOURCES ====================
resource "aws_s3_bucket" "terraform_state" {
  bucket = "cloudmart-tf-state-${var.team}"

  tags = {
    Project     = "cloudmart"
    Environment = var.environment
    Team        = var.team
    Owner       = var.owner_email
  }
}

resource "aws_dynamodb_table" "terraform_lock" {
  name         = "cloudmart-tf-lock"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  tags = {
    Project     = "cloudmart"
    Environment = var.environment
    Team        = var.team
    Owner       = var.owner_email
  }
}

# ==================== VPC ====================
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.5.0"

  name = "cloudmart-vpc"
  cidr = "10.0.0.0/16"

  azs              = ["ap-south-1a", "ap-south-1b"]
  public_subnets   = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnets  = ["10.0.11.0/24", "10.0.12.0/24"]
  database_subnets = ["10.0.21.0/24", "10.0.22.0/24"]

  enable_nat_gateway = true
  single_nat_gateway = true

  # Required tags for EKS to discover subnets
  public_subnet_tags = {
    "kubernetes.io/role/elb" = "1"
  }
  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = "1"
  }

  tags = {
    Project     = "cloudmart"
    Environment = var.environment
    Team        = var.team
    Owner       = var.owner_email
  }
}

# ==================== ECR REPOSITORIES ====================
resource "aws_ecr_repository" "services" {
  for_each = toset(["product-service", "order-service", "user-service", "notification-service", "frontend"])

  name                 = "cloudmart/${each.value}"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Project     = "cloudmart"
    Environment = var.environment
    Team        = var.team
    Owner       = var.owner_email
  }
}

# Separate resource for lifecycle policy (retain last 10 images — Section 3.2)
resource "aws_ecr_lifecycle_policy" "services" {
  for_each   = aws_ecr_repository.services
  repository = each.value.name

  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Keep only last 10 images per repository"
      selection = {
        tagStatus   = "any"
        countType   = "imageCountMoreThan"
        countNumber = 10
      }
      action = { type = "expire" }
    }]
  })
}

# ==================== DATA SOURCES ====================
# Resolves the "who ran terraform" identity — used for EKS access entry
data "aws_caller_identity" "current" {}

# ==================== EKS Cluster ====================
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "20.8.5"

  cluster_name    = var.cluster_name
  cluster_version = "1.30"

  vpc_id                          = module.vpc.vpc_id
  subnet_ids                      = module.vpc.private_subnets
  control_plane_subnet_ids        = module.vpc.public_subnets

  # Allow kubectl access from outside the VPC (your laptop)
  cluster_endpoint_public_access  = true
  cluster_endpoint_private_access = true

  # Use both Access Entry API and ConfigMap (safest for shared accounts)
  authentication_mode = "API_AND_CONFIG_MAP"

  # Grant YOUR isuru IAM user cluster-admin
  access_entries = {
    isuru_admin = {
      principal_arn     = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:user/isuru"
      kubernetes_groups = []

      policy_associations = {
        admin = {
          policy_arn   = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
          access_scope = {
            type = "cluster"
          }
        }
      }
    }
  }

  eks_managed_node_groups = {
    general = {
      min_size       = 2
      max_size       = 3
      desired_size   = 2
      instance_types = ["t3.small"]
      ami_type       = "AL2023_x86_64_STANDARD"
      capacity_type  = "ON_DEMAND"
    }
  }

  tags = {
    Project     = "cloudmart"
    Environment = var.environment
    Team        = var.team
    Owner       = var.owner_email
  }
}

# ==================== OUTPUTS ====================
output "ecr_repository_urls" {
  value = { for k, v in aws_ecr_repository.services : k => v.repository_url }
}

output "eks_cluster_name" {
  value = module.eks.cluster_name
}

output "vpc_id" {
  value = module.vpc.vpc_id
}

output "private_subnet_ids" {
  value = module.vpc.private_subnets
}

output "public_subnet_ids" {
  value = module.vpc.public_subnets
}

output "database_subnet_ids" {
  value = module.vpc.database_subnets
}