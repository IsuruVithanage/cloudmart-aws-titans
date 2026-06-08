# ==================== Observability Module ====================
# CloudWatch Dashboard, SNS Alerts, and Metric Alarms

# ==================== SNS Topic for Alerts ====================
resource "aws_sns_topic" "alerts" {
  name = "cloudmart-alerts"
  tags = var.tags
}

resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alarm_email
}

# ==================== Log-Based Metric Filter ====================
# Counts 5xx errors from product-service application logs shipped by Fluent Bit
# This avoids depending on ALB Target Group ARNs (which are managed by the LB Controller, not Terraform)

resource "aws_cloudwatch_log_group" "product_service" {
  name              = "/aws/containerinsights/${var.cluster_name}/application/product-service"
  retention_in_days = 7
  tags              = var.tags
}

resource "aws_cloudwatch_log_metric_filter" "product_5xx_errors" {
  name           = "cloudmart-product-service-5xx"
  log_group_name = aws_cloudwatch_log_group.product_service.name
  # Matches HTTP 5xx status codes in gunicorn/flask combined log format
  pattern = "[ip, user, timestamp, request, status_code=5*, size]"

  metric_transformation {
    name          = "ProductService5xxCount"
    namespace     = "CloudMart/Application"
    value         = "1"
    default_value = "0"
  }
}

resource "aws_cloudwatch_log_metric_filter" "product_all_requests" {
  name           = "cloudmart-product-service-requests"
  log_group_name = aws_cloudwatch_log_group.product_service.name
  # Matches all HTTP requests in combined log format
  pattern = "[ip, user, timestamp, request, status_code, size]"

  metric_transformation {
    name          = "ProductServiceRequestCount"
    namespace     = "CloudMart/Application"
    value         = "1"
    default_value = "0"
  }
}

# ==================== CloudWatch Alarm ====================
# Fires when product-service error rate exceeds 5% over 5 minutes
resource "aws_cloudwatch_metric_alarm" "product_service_errors" {
  alarm_name          = "cloudmart-product-service-high-error-rate"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  threshold           = 5
  alarm_description   = "ALERT: product-service 5xx error rate exceeded 5% over 5 minutes. Investigate immediately."
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]

  metric_query {
    id          = "error_rate"
    expression  = "IF(requests > 0, (errors / requests) * 100, 0)"
    label       = "Error Rate %"
    return_data = true
  }

  metric_query {
    id = "errors"
    metric {
      metric_name = "ProductService5xxCount"
      namespace   = "CloudMart/Application"
      period      = 300
      stat        = "Sum"
    }
  }

  metric_query {
    id = "requests"
    metric {
      metric_name = "ProductServiceRequestCount"
      namespace   = "CloudMart/Application"
      period      = 300
      stat        = "Sum"
    }
  }

  tags = var.tags
}

# ==================== CloudWatch Dashboard ====================
resource "aws_cloudwatch_dashboard" "cloudmart" {
  dashboard_name = "cloudmart-dashboard"

  dashboard_body = jsonencode({
    widgets = [
      # ---- Row 1: CPU Utilization per Service ----
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6
        properties = {
          title  = "CPU Utilization per Service"
          region = var.region
          metrics = [
            ["ContainerInsights", "pod_cpu_utilization", "Namespace", "cloudmart-prod", "PodName", "product-service", { label = "product-service" }],
            ["ContainerInsights", "pod_cpu_utilization", "Namespace", "cloudmart-prod", "PodName", "order-service", { label = "order-service" }],
            ["ContainerInsights", "pod_cpu_utilization", "Namespace", "cloudmart-prod", "PodName", "user-service", { label = "user-service" }],
            ["ContainerInsights", "pod_cpu_utilization", "Namespace", "cloudmart-prod", "PodName", "notification-service", { label = "notification-service" }],
            ["ContainerInsights", "pod_cpu_utilization", "Namespace", "cloudmart-prod", "PodName", "frontend", { label = "frontend" }],
          ]
          view   = "timeSeries"
          stacked = false
          period = 300
          stat   = "Average"
        }
      },

      # ---- Row 1: Memory Utilization per Service ----
      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 6
        properties = {
          title  = "Memory Utilization per Service"
          region = var.region
          metrics = [
            ["ContainerInsights", "pod_memory_utilization", "Namespace", "cloudmart-prod", "PodName", "product-service", { label = "product-service" }],
            ["ContainerInsights", "pod_memory_utilization", "Namespace", "cloudmart-prod", "PodName", "order-service", { label = "order-service" }],
            ["ContainerInsights", "pod_memory_utilization", "Namespace", "cloudmart-prod", "PodName", "user-service", { label = "user-service" }],
            ["ContainerInsights", "pod_memory_utilization", "Namespace", "cloudmart-prod", "PodName", "notification-service", { label = "notification-service" }],
            ["ContainerInsights", "pod_memory_utilization", "Namespace", "cloudmart-prod", "PodName", "frontend", { label = "frontend" }],
          ]
          view   = "timeSeries"
          stacked = false
          period = 300
          stat   = "Average"
        }
      },

      # ---- Row 2: SQS Queue Depth ----
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 12
        height = 6
        properties = {
          title  = "SQS Queue Depth (cloudmart-orders)"
          region = var.region
          metrics = [
            ["AWS/SQS", "ApproximateNumberOfMessagesVisible", "QueueName", var.sqs_queue_name, { label = "Messages Visible", color = "#FF6F00" }],
            ["AWS/SQS", "ApproximateNumberOfMessagesNotVisible", "QueueName", var.sqs_queue_name, { label = "Messages In-Flight", color = "#1E88E5" }],
          ]
          view   = "timeSeries"
          stacked = false
          period = 60
          stat   = "Average"
        }
      },

      # ---- Row 2: RDS Database Connections ----
      {
        type   = "metric"
        x      = 12
        y      = 6
        width  = 12
        height = 6
        properties = {
          title  = "RDS Database Connections (cloudmart-postgres)"
          region = var.region
          metrics = [
            ["AWS/RDS", "DatabaseConnections", "DBInstanceIdentifier", var.rds_instance_id, { label = "Active Connections", color = "#43A047" }],
          ]
          view   = "timeSeries"
          stacked = false
          period = 60
          stat   = "Average"
        }
      },

      # ---- Row 3: Product Service Error Rate (custom metric from log filter) ----
      {
        type   = "metric"
        x      = 0
        y      = 12
        width  = 12
        height = 6
        properties = {
          title  = "Product Service Error Rate (%)"
          region = var.region
          metrics = [
            [{ expression = "IF(m2 > 0, (m1 / m2) * 100, 0)", label = "Error Rate %", id = "e1", color = "#E53935" }],
            ["CloudMart/Application", "ProductService5xxCount", { id = "m1", visible = false }],
            ["CloudMart/Application", "ProductServiceRequestCount", { id = "m2", visible = false }],
          ]
          view   = "timeSeries"
          stacked = false
          period = 300
          stat   = "Sum"
          annotations = {
            horizontal = [
              { label = "Alarm Threshold (5%)", value = 5, color = "#FF0000" }
            ]
          }
        }
      },

      # ---- Row 3: Custom Metric — Orders Created Per Minute ----
      {
        type   = "metric"
        x      = 12
        y      = 12
        width  = 12
        height = 6
        properties = {
          title  = "Orders Created Per Minute"
          region = var.region
          metrics = [
            ["CloudMart/Orders", "OrdersCreated", "Service", "order-service", "Environment", "prod", { label = "Orders/min", stat = "Sum", color = "#7B1FA2" }],
          ]
          view   = "timeSeries"
          stacked = false
          period = 60
          stat   = "Sum"
        }
      },
    ]
  })
}
