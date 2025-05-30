# Configuring AWS provider for state management
provider "aws" {
  region = "eu-west-2" 
}

# Random string for unique bucket name
resource "random_string" "bucket_suffix" {
  length  = 8
  special = false
  upper   = false
}

# S3 bucket for Terraform state
resource "aws_s3_bucket" "terraform_state" {
  bucket        = "my-terraform-state-bucket-${random_string.bucket_suffix.result}"
  force_destroy = true # Allow deletion of non-empty bucket

  tags = {
    Name = "TerraformStateBucket"
  }
}

# DynamoDB table for state locking
resource "aws_dynamodb_table" "terraform_locks" {
  name         = "terraform-state-locks-${random_string.bucket_suffix.result}"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  tags = {
    Name = "TerraformLockTable"
  }
}

# Output the bucket name and DynamoDB table name for use in other configurations
output "state_bucket_name" {
  value = aws_s3_bucket.terraform_state.bucket
}

output "lock_table_name" {
  value = aws_dynamodb_table.terraform_locks.name
}