variable "cluster_name" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "private_subnets" {
  type = list(string)
}

variable "public_subnets" {
  type = list(string)
}

variable "tags" {
  type = map(string)
}

variable "cluster_admin_users" {
  description = "List of IAM usernames to be granted cluster admin permissions"
  type        = list(string)
  default     = []
}