output "rds_endpoint"         { value = aws_db_instance.postgres.endpoint }
output "dynamodb_table_name"  { value = aws_dynamodb_table.products.name }
output "sqs_queue_url"        { value = aws_sqs_queue.orders.url }
output "assets_bucket_name"   { value = aws_s3_bucket.assets.bucket }
output "secret_arn" {
  value = aws_secretsmanager_secret.db_password.arn
}
output "ses_email" {
  value = aws_ses_email_identity.sender.email
}

output "ses_identity_arn" {
  value = "arn:aws:ses:ap-south-1:854215217603:identity/${aws_ses_email_identity.sender.email}"
}