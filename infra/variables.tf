variable "environment" {
description = "Deployment environment"
type        = string
default     = "prod"
}

variable "cluster_name" {
description = "EKS cluster name"
type        = string
default     = "cloudmart-eks"
}

variable "team" {
description = "Team identifier for resource tagging"
type        = string
default     = "team-titans"
}

variable "owner_email" {
description = "Owner email for resource tagging"
type        = string
default     = "isuruvithanagemv@gmail.com"
}

variable "region" {
description = "AWS region"
type        = string
default     = "ap-south-1"
}

variable "db_password" {
description = "RDS master password"
type        = string
sensitive   = true
}
