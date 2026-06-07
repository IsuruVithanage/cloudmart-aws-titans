output "rds_endpoint"         { value = aws_db_instance.postgres.endpoint }
output "dynamodb_table_name"  { value = aws_dynamodb_table.products.name }
output "sqs_queue_url"        { value = aws_sqs_queue.orders.url }
output "assets_bucket_name"   { value = aws_s3_bucket.assets.bucket }
