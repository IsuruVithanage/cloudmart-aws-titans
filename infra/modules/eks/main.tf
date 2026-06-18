data "aws_caller_identity" "current" {}

module "eks" {
source  = "terraform-aws-modules/eks/aws"
version = "20.8.5"

cluster_name    = var.cluster_name
cluster_version = "1.36"

vpc_id                         = var.vpc_id
subnet_ids                     = var.private_subnets
control_plane_subnet_ids       = var.public_subnets

cluster_endpoint_public_access  = true
cluster_endpoint_private_access = true
authentication_mode             = "API_AND_CONFIG_MAP"

enable_cluster_creator_admin_permissions = true

# ==================== Observability ====================
# Deploys CloudWatch Agent (Container Insights metrics) + Fluent Bit (log shipping)
# Also includes X-Ray daemon for distributed tracing [D]
/*cluster_addons = {
  amazon-cloudwatch-observability = {
    most_recent = true
  }
}
*/

eks_managed_node_groups = {
general = {
min_size       = 2
max_size       = 3
desired_size   = 3
instance_types = ["t3.small"]
ami_type       = "AL2023_x86_64_STANDARD"
capacity_type  = "ON_DEMAND"

  metadata_options = {
    http_endpoint               = "enabled"
    http_tokens                 = "required"  # enforces IMDSv2
    http_put_response_hop_limit = 2
  }

  # IAM policies for observability — Section 3.6 [M] + [D]
  iam_role_additional_policies = {
    CloudWatchAgent = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
    XRay            = "arn:aws:iam::aws:policy/AWSXRayDaemonWriteAccess"
    EC2ReadOnly     = "arn:aws:iam::aws:policy/AmazonEC2ReadOnlyAccess"
  }
}
}

tags = var.tags
}