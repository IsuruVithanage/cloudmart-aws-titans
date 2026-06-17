terraform {
  backend "s3" {
    bucket       = "team-titans-cloudmart-tf-state"
    key          = "cloudmart/terraform.tfstate"
    region       = "ap-south-1"
    use_lockfile = true
    encrypt      = true
    dynamodb_table = "cloudmart-tf-lock"
  }
}