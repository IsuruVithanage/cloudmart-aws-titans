variable "database_subnets" {
  type = list(string)
}

variable "database_sg_id" {
  type = string
}

variable "db_password" {
  type      = string
  sensitive = true
}

variable "team" {
  type = string
}

variable "tags" {
  type = map(string)
}

variable "ses_email" {
  description = "Verified SES sender email address"
  type        = string
}