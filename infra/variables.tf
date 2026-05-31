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