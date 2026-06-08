# Networking
output "vpc_id"              { value = module.networking.vpc_id }
output "public_subnet_ids"   { value = module.networking.public_subnets }
output "private_subnet_ids"  { value = module.networking.private_subnets }
output "database_subnet_ids" { value = module.networking.database_subnets }
output "bastion_sg_id"       { value = module.networking.bastion_sg_id }
output "load_balancer_sg_id" { value = module.networking.load_balancer_sg_id }
output "database_sg_id"      { value = module.networking.database_sg_id }

# EKS
output "eks_cluster_name"    { value = module.eks.cluster_name }
output "eks_cluster_endpoint"{ value = module.eks.cluster_endpoint }

# ECR
output "ecr_repository_urls" { value = module.ecr.repository_urls }

# Data Services
output "rds_endpoint"        { value = module.data_services.rds_endpoint }
output "dynamodb_table_name" { value = module.data_services.dynamodb_table_name }
output "sqs_queue_url"       { value = module.data_services.sqs_queue_url }
output "assets_bucket_name"  { value = module.data_services.assets_bucket_name }
output "secret_arn" {
  value = module.data_services.secret_arn
}
output "ses_email" {
  value = module.data_services.ses_email
}

output "ses_identity_arn" {
  value = module.data_services.ses_identity_arn
}
