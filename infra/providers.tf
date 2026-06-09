terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "ap-south-1"

  default_tags {
    tags = {
      Project     = var.Project
      Environment = var.environment
      Team        = var.team
      Owner       = var.owner_email
    }
  }
}