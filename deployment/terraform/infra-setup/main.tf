# Backend Setup - Word Dictionary
# Creates S3 bucket and DynamoDB table for Terraform remote state
# Run this FIRST before deploying any environment

terraform {
  required_version = ">= 1.0.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}
variable "aws_region" {
    description = "AWS region for state storage"
    type        = string
    default     = "eu-north-1"
}

variable "service_name" {
    description = "Service name for kubernetes labels"
    type        = string
    default     = "sm-wikidict"
}

provider "aws" {
  region = var.aws_region
}

# S3 Bucket for Terraform State (Shared across all projects)
resource "aws_s3_bucket" "terraform_state" {
  bucket = "sm-terraform-state-370260028560"  # Must be globally unique

  lifecycle {
    prevent_destroy = true
  }

  tags = {
    Name      = "sm-terraform-state-370260028560"
    Purpose   = "Terraform state storage for all projects"
    ManagedBy = "terraform"
  }
}

# Enable versioning for state history
resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Enable server-side encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "aws:kms"
    }
  }
}

# Block public access
resource "aws_s3_bucket_public_access_block" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# DynamoDB table for state locking (Shared across all projects)
resource "aws_dynamodb_table" "terraform_locks" {
  name         = "terraform-state-locks"  # Generic table name
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  tags = {
    Name      = "terraform-state-locks"
    Purpose   = "Terraform state locking for all projects"
    ManagedBy = "terraform"
  }
}

# Outputs
output "s3_bucket_name" {
  description = "S3 bucket name for Terraform state"
  value       = aws_s3_bucket.terraform_state.id
}

output "dynamodb_table_name" {
  description = "DynamoDB table name for state locking"
  value       = aws_dynamodb_table.terraform_locks.name
}

output "backend_config" {
  description = "Backend configuration to add to environment terraform blocks"
  value       = <<-EOT
    backend "s3" {
      bucket         = "${aws_s3_bucket.terraform_state.id}"
      key            = "<project-name>/<component>/terraform.tfstate"
      region         = "${var.aws_region}"
      encrypt        = true
      dynamodb_table = "${aws_dynamodb_table.terraform_locks.name}"
    }

    Example for WikiDict ECR:
      key = "wikidict-service/ecr/terraform.tfstate"

    Example for WikiDict Cluster:
      key = "wikidict-service/cluster/terraform.tfstate"
  EOT
}
