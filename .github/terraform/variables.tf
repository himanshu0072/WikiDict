variable "region" {
  description = ""
  type = string
  default = "eu-north-1"
}
variable "project_name" {
  description = "Project name used for resource naming and tagging"
  type        = string
  default     = "sm-wikidict"
}

variable "repository_name" {
  description = "Name of the ECR repository"
  type = string
  default = "wikidict_service"
}

variable "repository_description" {
  description = "Description for the ECR repository catalog"
  type        = string
  default     = <<-EOT
    # SM-WikiDict

    A fast, high-performance dictionary service powered by Fake data.

    ## Features
    - Sub-40ms p99 latency with in-memory index lookups
    - Cost-efficient object storage + byte-range reads
    - Scalable (100K to 10M+ lookups per month)
    - Zero downtime updates with blue-green deployment

    ## Tech Stack
    - Python + FastAPI
    - AWS EKS + Terraform
    - S3 storage with optimized byte-range reads
  EOT
}

# variable "attach_to_existing_user" {
#   description = "Whether to attach ECR policy to an existing IAM user"
#   type        = bool
#   default     = true
# }

# variable "existing_iam_user_name" {
#   description = "Name of existing IAM user to attach ECR policy to (if attach_to_existing_user is true)"
#   type        = string
#   default     = "wikidict-service"
# }