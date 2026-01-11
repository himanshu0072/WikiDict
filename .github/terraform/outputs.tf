# ============================================================================
# OUTPUTS - ECR Public Infrastructure
# ============================================================================

output "repository_arn" {
  description = "ARN of the ECR Public repository"
  value       = aws_ecrpublic_repository.wikidict.arn
}

output "repository_uri" {
  description = "URI of the ECR Public repository (use this in GitHub Actions)"
  value       = aws_ecrpublic_repository.wikidict.repository_uri
}

output "repository_registry_id" {
  description = "Registry ID for the ECR Public repository"
  value       = aws_ecrpublic_repository.wikidict.registry_id
}

output "repository_name" {
  description = "Name of the ECR Public repository"
  value       = aws_ecrpublic_repository.wikidict.repository_name
}

output "iam_policy_arn" {
  description = "ARN of the IAM policy for GitHub Actions ECR access"
  value       = aws_iam_policy.github_actions_ecr.arn
}

output "iam_policy_name" {
  description = "Name of the IAM policy for GitHub Actions ECR access"
  value       = aws_iam_policy.github_actions_ecr.name
}