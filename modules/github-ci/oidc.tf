resource "aws_iam_openid_connect_provider" "aws_iam_oidc_github_action" {
  url = "https://token.actions.githubusercontent.com"

  client_id_list = [
    "sts.amazonaws.com",
  ]

  tags = {
    environment   = var.environment
    application   = "${var.environment}-lambda-requests"
    oidc_provider = "Github"
  }
}