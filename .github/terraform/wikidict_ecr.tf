# ============================================================================
# ECR PUBLIC REPOSITORY
# ============================================================================
#
# Creates a public container registry for WikiDict Docker images
#
# Benefits of ECR Public:
#   ✓ 50 GB storage (FREE)
#   ✓ 500 GB data transfer out per month (FREE)
#   ✓ Public access (good for open source projects)
#
# Limitations:
#   - Must be in us-east-1 region
#   - Images are publicly accessible
#
# ============================================================================

resource "aws_ecrpublic_repository" "wikidict" {
  repository_name = var.repository_name

  catalog_data {
    about_text = var.repository_description

    description = "WikiDict - Fast, high-performance dictionary service powered by Wikipedia"

    architectures = ["x86-64"]

    operating_systems = ["Linux"]

    usage_text = <<-EOT
      ## Quick Start

      ```bash
      # Pull the image
      docker pull ${var.repository_name}:latest

      # Run the container
      docker run -p 8000:8000 ${var.repository_name}:latest

      # Access the API
      curl http://localhost:8000/health
      ```

      ## Environment Variables
      - `AWS_BUCKET_NAME` - S3 bucket for WikiDict data
      - `AWS_REGION` - AWS region (default: eu-north-1)

      ## Documentation
      Visit: https://github.com/saurabhmaurya45/WikiDict
    EOT
  }

  tags = merge(local.common_tags, {
    Name = var.repository_name
  })
}