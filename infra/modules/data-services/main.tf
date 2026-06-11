# ==================== RDS PostgreSQL — user-service ====================
resource "aws_db_subnet_group" "cloudmart" {
name       = "cloudmart-db-subnet-group"
subnet_ids = var.database_subnets
tags       = var.tags
}

resource "aws_db_instance" "postgres" {
identifier              = "cloudmart-postgres"
engine                  = "postgres"
instance_class          = "db.t3.micro"
allocated_storage       = 20
db_name                 = "cloudmart"
username                = "cloudmart_admin"
password                = var.db_password
db_subnet_group_name    = aws_db_subnet_group.cloudmart.name
vpc_security_group_ids  = [var.database_sg_id]
skip_final_snapshot     = true
deletion_protection     = false
storage_encrypted       = true
backup_retention_period = 1
backup_window           = "02:00-03:00"
multi_az                = true   
tags                    = var.tags
}

# ==================== DynamoDB — product-service ====================
resource "aws_dynamodb_table" "products" {
name         = "cloudmart-products"
billing_mode = "PAY_PER_REQUEST"
hash_key     = "id"

attribute {
name = "id"
type = "S"
}

tags = var.tags
}

# ==================== SQS Queue — order events ====================
resource "aws_sqs_queue" "orders" {
name                      = "cloudmart-orders"
message_retention_seconds = 86400
tags                      = var.tags
}

# ==================== S3 — static assets ====================
resource "aws_s3_bucket" "assets" {
bucket = "cloudmart-assets-${var.team}"
tags   = var.tags
}

resource "aws_s3_bucket_versioning" "assets" {
bucket = aws_s3_bucket.assets.id
versioning_configuration {
status = "Enabled"
}
}

# ==================== S3 — Terraform state ====================
resource "aws_s3_bucket" "terraform_state" {
bucket = "cloudmart-tf-state-${var.team}"
tags   = var.tags
}

resource "aws_s3_bucket_versioning" "terraform_state" {
bucket = aws_s3_bucket.terraform_state.id
versioning_configuration {
status = "Enabled"
}
}

resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
bucket = aws_s3_bucket.terraform_state.id
rule {
apply_server_side_encryption_by_default {
sse_algorithm = "AES256"
}
}
}

# ==================== DynamoDB — Terraform lock ====================
resource "aws_dynamodb_table" "terraform_lock" {
name         = "cloudmart-tf-lock"
billing_mode = "PAY_PER_REQUEST"
hash_key     = "LockID"

attribute {
name = "LockID"
type = "S"
}

tags = var.tags
}

# ==================== SECRETS MANAGER — user-service DB password ====================
resource "aws_secretsmanager_secret" "db_password" {
  name        = "cloudmart/user-service/db-password"
  description = "RDS PostgreSQL password for user-service"

  tags = var.tags
}

resource "aws_secretsmanager_secret_version" "db_password" {
  secret_id = aws_secretsmanager_secret.db_password.id
  secret_string = jsonencode({
    DB_PASSWORD = var.db_password
    DB_HOST     = aws_db_instance.postgres.endpoint
    DB_NAME     = "cloudmart"
    DB_USER     = "cloudmart_admin"
  })
}

# ==================== SES — notification-service ====================
resource "aws_ses_email_identity" "sender" {
  email = var.ses_email
}
