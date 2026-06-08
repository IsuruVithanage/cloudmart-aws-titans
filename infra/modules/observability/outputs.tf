output "dashboard_name" {
  description = "CloudWatch dashboard name"
  value       = aws_cloudwatch_dashboard.cloudmart.dashboard_name
}

output "sns_topic_arn" {
  description = "SNS topic ARN for alert notifications"
  value       = aws_sns_topic.alerts.arn
}
