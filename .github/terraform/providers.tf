# ============================================================================
# ECR Public Infrastructure - WikiDict Container Registry
# ============================================================================
#
# This Terraform configuration creates:
#   - ECR Public Repository for Docker images
#   - IAM policies for GitHub Actions to push/pull images
#
# Purpose: One-time setup for container registry infrastructure
# Region: Must be us-east-1 (ECR Public requirement)
#
# ============================================================================

terraform {
  required_version = ">= 1.0.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Optional: Uncomment after creating S3 backend in infra-setup
  backend "s3" {
    bucket         = "sm-terraform-state-370260028560"
    key            = "wikidict-service/ecr/terraform.tfstate"
    region         = "eu-north-1"
    encrypt        = true
    dynamodb_table = "terraform-state-locks"
  }
}

# ============================================================================
# PROVIDER CONFIGURATION
# ============================================================================

# ECR Public MUST use us-east-1 region
provider "aws" {
  region = "us-east-1"

  default_tags {
    tags = {
      Project   = var.project_name
      ManagedBy = "Terraform"
      Component = "ECR"
    }
  }
}

# ============================================================================
# LOCAL VARIABLES
# ============================================================================

locals {
  common_tags = {
    Project     = var.project_name
    Environment = "shared"  # ECR is shared across all environments
    ManagedBy   = "Terraform"
  }
}
