########################################
# Terraform Backend
########################################
terraform {
  backend "s3" {
    bucket         = "my-terraform-state-bucket-76474"
    key            = "stage/data-stores/mysql/terraform.tfstate"
    region         = "us-east-2"
    dynamodb_table = "terraform-state-locks"
    encrypt        = true
  }
}

########################################
# Provider
########################################
provider "aws" {
  region = "us-west-2"
}

########################################
# RDS MySQL Instance
########################################
resource "aws_db_instance" "example" {
  identifier_prefix = "terraform-up-and-running"
  engine            = "mysql"
  engine_version    = "8.0.43"      # specific supported version
  instance_class    = "db.t3.micro" # compatible with MySQL 8
  allocated_storage = 10
  db_name           = "example_database"

  username = var.db_username
  password = var.db_password

  skip_final_snapshot = true
}