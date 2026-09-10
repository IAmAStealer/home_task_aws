output "github_action_role_arn" {
  description = "IAM role ARN GitHub Actions assumes via OIDC to deploy this environment"
  value       = aws_iam_role.iam_role_github_action.arn
}
