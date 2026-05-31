variable "environment" {
  description = "Deployment environment"
  default     = "prod"
}

variable "cluster_name" {
  default = "cloudmart-eks"
}

variable "team" {
  default = "team-titans"
}

variable "owner_email" {
  description = "Owner email for resource tagging"
  default     = "isuruvithanagemv@gmail.com"
}

variable "db_password" {
  description = "RDS master password — do not commit, pass via env or tfvars"
  sensitive   = true
}