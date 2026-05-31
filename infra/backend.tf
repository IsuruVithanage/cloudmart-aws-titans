terraform {
  backend "s3" {
    bucket         = "cloudmart-tf-state-team-titans"
    key            = "cloudmart/terraform.tfstate"
    region         = "ap-south-1"
    dynamodb_table = "cloudmart-tf-lock"
    encrypt        = true
  }
}
