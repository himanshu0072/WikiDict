# ============================================================================
# OUTPUTS
# ============================================================================
#
# Outputs = Values that Terraform displays after `terraform apply`
#           Also can be used by other Terraform configurations
#
# ============================================================================

# ----------------------------------------------------------------------------
# VPC OUTPUTS
# ----------------------------------------------------------------------------

output "vpc_id" {
  description = "The ID of the VPC"
  value       = aws_vpc.main.id
}

output "public_subnet_ids" {
  description = "List of public subnet IDs"
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "List of private subnet IDs"
  value       = aws_subnet.private[*].id
}

# ----------------------------------------------------------------------------
# EKS OUTPUTS
# ----------------------------------------------------------------------------

output "cluster_name" {
  description = "Name of the EKS cluster"
  value       = aws_eks_cluster.main.name
}

output "cluster_endpoint" {
  description = "Endpoint URL for the EKS cluster API"
  value       = aws_eks_cluster.main.endpoint
}

output "cluster_certificate_authority" {
  description = "Certificate authority data for the cluster"
  value       = aws_eks_cluster.main.certificate_authority[0].data
  sensitive   = true  # Hide in logs (security)
}

# ----------------------------------------------------------------------------
# ECR OUTPUTS
# ----------------------------------------------------------------------------

output "ecr_repository_url" {
  description = "URL of the ECR repository (use this in docker push)"
  value       = aws_ecr_repository.main.repository_url
}

# ----------------------------------------------------------------------------
# HELPFUL COMMANDS
# ----------------------------------------------------------------------------

output "configure_kubectl" {
  description = "Run this command to configure kubectl"
  value       = "aws eks update-kubeconfig --region ${var.aws_region} --name ${aws_eks_cluster.main.name}"
}

output "docker_login_command" {
  description = "Run this command to login to ECR"
  value       = "aws ecr get-login-password --region ${var.aws_region} | docker login --username AWS --password-stdin ${aws_ecr_repository.main.repository_url}"
}

output "namespaces_created" {
  description = "Kubernetes namespaces created for each environment"
  value       = var.environments
}
