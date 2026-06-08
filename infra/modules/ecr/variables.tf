variable "service_names" {
  type    = list(string)
  default = ["product-service", "order-service", "user-service", "notification-service", "frontend"]
}

variable "tags" {
  type = map(string)
}