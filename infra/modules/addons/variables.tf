variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "alb_controller_role_arn" {
  description = "IAM Role ARN for AWS Load Balancer Controller"
  type        = string
}

variable "external_secrets_role_arn" {
  description = "IAM Role ARN for External Secrets Operator"
  type        = string
}

variable "keda_role_arn" {
  description = "IAM Role ARN for KEDA"
  type        = string
}

variable "db_secret_arn" {
  description = "ARN of the Secrets Manager secret containing DB credentials"
  type        = string
}