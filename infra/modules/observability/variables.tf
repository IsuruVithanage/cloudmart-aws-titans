variable "cluster_name" {
  description = "EKS cluster name for Container Insights metrics"
  type        = string
}

variable "region" {
  description = "AWS region"
  type        = string
}

variable "rds_instance_id" {
  description = "RDS instance identifier for DB connection metrics"
  type        = string
  default     = "cloudmart-postgres"
}

variable "sqs_queue_name" {
  description = "SQS queue name for queue depth metrics"
  type        = string
  default     = "cloudmart-orders"
}

variable "alarm_email" {
  description = "Email address for CloudWatch alarm notifications"
  type        = string
}

variable "tags" {
  description = "Resource tags"
  type        = map(string)
}
