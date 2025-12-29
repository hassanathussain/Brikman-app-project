########################################
# Provider
########################################
provider "aws" {
  region = "us-west-2"
}

########################################
# Backend
########################################
terraform {
  backend "s3" {
    bucket         = "my-terraform-state-bucket-76474"
    key            = "terraform/stage/services/terraform.tfstate"
    region         = "us-east-2" # ← FIXED
    dynamodb_table = "terraform-state-locks"
    encrypt        = true
  }
}