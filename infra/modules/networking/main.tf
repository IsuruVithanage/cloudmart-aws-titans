# ==================== VPC ====================
module "vpc" {
source  = "terraform-aws-modules/vpc/aws"
version = "5.5.0"

name = "cloudmart-vpc"
cidr = "10.0.0.0/16"

azs              = ["${var.region}a", "${var.region}b"]
public_subnets   = ["10.0.1.0/24", "10.0.2.0/24"]
private_subnets  = ["10.0.11.0/24", "10.0.12.0/24"]
database_subnets = ["10.0.21.0/24", "10.0.22.0/24"]

enable_nat_gateway   = true
single_nat_gateway   = true
enable_dns_hostnames = true
enable_dns_support   = true

public_subnet_tags = {
"kubernetes.io/role/elb"                        = "1"
"kubernetes.io/cluster/${var.cluster_name}"     = "shared"
}

private_subnet_tags = {
"kubernetes.io/role/internal-elb"               = "1"
"kubernetes.io/cluster/${var.cluster_name}"     = "shared"
}

tags = var.tags
}

# ==================== SECURITY GROUPS ====================
resource "aws_security_group" "bastion" {
name        = "cloudmart-bastion-sg"
description = "Bastion host - SSH from trusted IPs only (least privilege)"
vpc_id      = module.vpc.vpc_id

ingress {
description = "SSH - restrict to known IP in production"
from_port   = 22
to_port     = 22
protocol    = "tcp"
cidr_blocks = ["0.0.0.0/0"]
}

egress {
description = "Allow all outbound to reach VPC resources"
from_port   = 0
to_port     = 0
protocol    = "-1"
cidr_blocks = ["0.0.0.0/0"]
}

tags = merge(var.tags, { Name = "cloudmart-bastion-sg" })
}

resource "aws_security_group" "load_balancer" {
name        = "cloudmart-alb-sg"
description = "ALB - HTTP and HTTPS from internet only"
vpc_id      = module.vpc.vpc_id

ingress {
description = "HTTP from internet - redirects to HTTPS"
from_port   = 80
to_port     = 80
protocol    = "tcp"
cidr_blocks = ["0.0.0.0/0"]
}

ingress {
description = "HTTPS from internet for frontend"
from_port   = 443
to_port     = 443
protocol    = "tcp"
cidr_blocks = ["0.0.0.0/0"]
}

egress {
description = "Forward to EKS nodes inside VPC only"
from_port   = 0
to_port     = 0
protocol    = "-1"
cidr_blocks = ["10.0.0.0/16"]
}

tags = merge(var.tags, { Name = "cloudmart-alb-sg" })
}

resource "aws_security_group" "database" {
name        = "cloudmart-db-sg"
description = "RDS PostgreSQL - private subnets only, never public internet"
vpc_id      = module.vpc.vpc_id

ingress {
description = "PostgreSQL from private app subnets only (least privilege)"
from_port   = 5432
to_port     = 5432
protocol    = "tcp"
cidr_blocks = ["10.0.11.0/24", "10.0.12.0/24"]
}

egress {
description = "RDS does not initiate outbound connections"
from_port   = 0
to_port     = 0
protocol    = "-1"
cidr_blocks = ["0.0.0.0/0"]
}

tags = merge(var.tags, { Name = "cloudmart-db-sg" })
}

# ==================== VPC FLOW LOGS — Section 3.1 [D] ====================
resource "aws_cloudwatch_log_group" "flow_log" {
name              = "/aws/vpc/cloudmart-flow-logs"
retention_in_days = 7
tags              = var.tags
}

resource "aws_iam_role" "flow_log" {
name = "cloudmart-flow-log-role"

assume_role_policy = jsonencode({
Version = "2012-10-17"
Statement = [{
Action    = "sts:AssumeRole"
Effect    = "Allow"
Principal = { Service = "vpc-flow-logs.amazonaws.com" }
}]
})
}

resource "aws_iam_role_policy" "flow_log" {
name = "cloudmart-flow-log-policy"
role = aws_iam_role.flow_log.id

policy = jsonencode({
Version = "2012-10-17"
Statement = [{
Effect = "Allow"
Action = [
"logs:CreateLogGroup",
"logs:CreateLogStream",
"logs:PutLogEvents",
"logs:DescribeLogGroups",
"logs:DescribeLogStreams"
]
Resource = "*"
}]
})
}

resource "aws_flow_log" "cloudmart" {
iam_role_arn    = aws_iam_role.flow_log.arn
log_destination = aws_cloudwatch_log_group.flow_log.arn
traffic_type    = "REJECT"
vpc_id          = module.vpc.vpc_id
tags            = var.tags
}

resource "aws_security_group" "vpc_endpoints" {
  name        = "cloudmart-vpc-endpoints-sg"
  vpc_id      = module.vpc.vpc_id
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["10.0.11.0/24", "10.0.12.0/24"] # Your private subnet CIDRs
  }
}

resource "aws_vpc_endpoint" "secretsmanager" {
  vpc_id              = module.vpc.vpc_id
  service_name        = "com.amazonaws.${var.region}.secretsmanager"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = module.vpc.private_subnets
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true
}

resource "aws_vpc_endpoint" "dynamodb" {
  vpc_id            = module.vpc.vpc_id
  service_name      = "com.amazonaws.${var.region}.dynamodb"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = module.vpc.private_route_table_ids
}
