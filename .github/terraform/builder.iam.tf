# ============================================================================
# IAM POLICY FOR GITHUB ACTIONS
# ============================================================================
#
# This policy allows GitHub Actions to:
#   - Authenticate with ECR Public
#   - Push Docker images
#   - List/describe images
#   - Delete old images (for cleanup workflow)
#
# Note: This matches the permissions you're already using in workflows
#
# ============================================================================

data "aws_iam_policy_document" "github_actions_ecr" {
  # Allow getting auth token for ECR Public
  statement {
    sid = "ECRPublicAuth"
    actions = [
      "ecr-public:GetAuthorizationToken",
      "sts:GetServiceBearerToken"
    ]
    resources = ["*"]
  }

  # Allow push/pull/delete operations on the repository
  statement {
    sid = "ECRPublicRepositoryAccess"
    actions = [
      "ecr-public:BatchCheckLayerAvailability",
      "ecr-public:GetRepositoryPolicy",
      "ecr-public:DescribeRepositories",
      "ecr-public:DescribeImages",
      "ecr-public:DescribeImageTags",
      "ecr-public:InitiateLayerUpload",
      "ecr-public:UploadLayerPart",
      "ecr-public:CompleteLayerUpload",
      "ecr-public:PutImage",
      "ecr-public:BatchDeleteImage"  # For cleanup workflow
    ]
    resources = [aws_ecrpublic_repository.wikidict.arn]
  }
}

# Create the IAM policy
resource "aws_iam_policy" "github_actions_ecr" {
  name        = "${var.project_name}-github-actions-ecr-public"
  description = "Policy for GitHub Actions to push/pull/manage images in ECR Public"
  policy      = data.aws_iam_policy_document.github_actions_ecr.json

  tags = local.common_tags
}

resource "aws_iam_user" "github_actions" {
  name = "${var.project_name}-github-actions"
  path = "/cicd/"

  tags = merge(local.common_tags, {
    Purpose = "GitHub Actions CI/CD"
  })
}

resource "aws_iam_user_policy_attachment" "github_actions_ecr" {
  user       = aws_iam_user.github_actions.name
  policy_arn = aws_iam_policy.github_actions_ecr.arn
}

# ============================================================================
# ATTACH POLICY TO EXISTING IAM USER
# ============================================================================
#
# If you have an existing IAM user (like 'wikidict-service'),
# attach this policy to it
#
# ============================================================================

# resource "aws_iam_user_policy_attachment" "existing_user_ecr" {
#   count = var.attach_to_existing_user ? 1 : 0

#   user       = var.existing_iam_user_name
#   policy_arn = aws_iam_policy.github_actions_ecr.arn
# }