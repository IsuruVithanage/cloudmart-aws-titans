# ==================== LOCALS ====================
locals {
  tags = {
    Project     = "cloudmart"
    Environment = var.environment
    Team        = var.team
    Owner       = var.owner_email
  }
}

# ==================== NETWORKING ====================
module "networking" {
  source       = "./modules/networking"
  region       = "ap-south-1"
  cluster_name = var.cluster_name
  tags         = local.tags
}

# ==================== EKS ====================
module "eks" {
  source          = "./modules/eks"
  cluster_name    = var.cluster_name
  vpc_id          = module.networking.vpc_id
  private_subnets = module.networking.private_subnets
  public_subnets  = module.networking.public_subnets
  tags            = local.tags
}

# ==================== ECR ====================
module "ecr" {
  source = "./modules/ecr"
  tags   = local.tags
}

# ==================== DATA SERVICES ====================
module "data_services" {
  source           = "./modules/data-services"
  database_subnets = module.networking.database_subnets
  database_sg_id   = module.networking.database_sg_id
  db_password      = var.db_password
  team             = var.team
  tags             = local.tags
  ses_email        = var.ses_email
  test_recipient_emails = var.test_recipient_emails
}

# ==================== OBSERVABILITY ====================
module "observability" {
  source          = "./modules/observability"
  cluster_name    = var.cluster_name
  region          = var.region
  rds_instance_id = "cloudmart-postgres"
  sqs_queue_name  = "cloudmart-orders"
  alarm_email     = var.owner_email
  tags            = local.tags
}

# ============================================================
# ALB → EKS Node Security Group Rules
# These rules allow the ALB to reach frontend (port 80) and
# backend services (ports 8001-8003) on the EKS worker nodes.
# ============================================================

resource "aws_security_group_rule" "alb_to_eks_nodes_http" {
  type                     = "ingress"
  from_port                = 80
  to_port                  = 80
  protocol                 = "tcp"
  security_group_id        = module.eks.node_security_group_id
  source_security_group_id = module.networking.load_balancer_sg_id
  description              = "Allow ALB to reach frontend pods on port 80"
}

resource "aws_security_group_rule" "alb_to_eks_nodes_backends" {
  type                     = "ingress"
  from_port                = 8001
  to_port                  = 8003
  protocol                 = "tcp"
  security_group_id        = module.eks.node_security_group_id
  source_security_group_id = module.networking.load_balancer_sg_id
  description              = "Allow ALB to reach backend services (product:8001, order:8002, user:8003)"
}