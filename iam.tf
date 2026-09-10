
resource "aws_iam_role" "iam_role_github_action" {
  name        = "${var.environment}-iam-role-github-action"
  description = "IAM role for github action"
  # Terraform's "jsonencode" function converts a
  # Terraform expression result to valid JSON syntax.
  assume_role_policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Principal" : {
          "Federated" : "${aws_iam_openid_connect_provider.aws_iam_oidc_github_action.arn}"
        },
        "Action" : [
          "sts:AssumeRoleWithWebIdentity",
          "sts:TagSession"
        ],
        "Condition" : {
          "StringEquals" : {
            "token.actions.githubusercontent.com:aud" : "sts.amazonaws.com",
            "token.actions.githubusercontent.com:sub" : "repo:IAmAStealer@24506305/home_task_aws@1360249375:ref:refs/heads/main"
          }
        }
      }
    ]
  })

  tags = {
    environment   = var.environment
    application   = "lambda-requests"
    oidc-provider = "Github"
  }
}

# kms:ListAliases logically targets a wildcard because it is about listing every alias in the account, not one in particular
#tfsec:ignore:aws-iam-no-policy-wildcards
resource "aws_iam_role_policy" "iam_role_policy_github_action" {
  name = "${var.environment}-iam-role-policy-lambda-requests"
  role = aws_iam_role.iam_role_github_action.id
  # Terraform's "jsonencode" function converts a
  # Terraform expression result to valid JSON syntax.
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "kms:DescribeKey",
          "kms:GetKeyPolicy",
          "kms:PutKeyPolicy",
          "kms:CreateKey",
          "kms:CreateAlias",
          "kms:DeleteAlias",
          "kms:UpdateAlias",
          "kms:UpdateKeyDescription",
          "kms:EnableKeyRotation",
          "kms:DisableKeyRotation",
          "kms:ScheduleKeyDeletion",
          "kms:CancelKeyDeletion",
          "kms:TagResource",
          "kms:UntagResource",
          "kms:GetKeyRotationStatus",
          "kms:ListResourceTags"
        ]
        Effect   = "Allow"
        Resource = module.health_api.kms_key_arn
      },
      {
        Action = [
          "kms:ListAliases",
        ]
        Effect   = "Allow"
        Resource = "*"
      },
      {
        Action = [
          "dynamodb:DescribeTable",
          "dynamodb:ListTagsOfResource",
          "dynamodb:CreateTable",
          "dynamodb:DeleteTable",
          "dynamodb:UpdateTable",
          "dynamodb:TagResource",
          "dynamodb:UntagResource",
          "dynamodb:UpdateContinuousBackups",
          "dynamodb:DescribeContinuousBackups",
          "dynamodb:DescribeTimeToLive",
        ]
        Effect   = "Allow"
        Resource = module.health_api.dynamodb_table_arn
      },
      {
        Action = [
          "lambda:CreateFunction",
          "lambda:GetFunction",
          "lambda:ListVersionsByFunction",
          "lambda:GetFunctionCodeSigningConfig",
          "lambda:GetFunctionEventInvokeConfig",
          "lambda:GetRuntimeManagementConfig",
          "lambda:DeleteFunction",
          "lambda:UpdateFunctionConfiguration",
          "lambda:GetPolicy",
          "lambda:UpdateFunctionCode",
          "lambda:AddPermission",
          "lambda:RemovePermission",
          "lambda:TagResource",
          "lambda:UntagResource",
        ]
        Effect   = "Allow"
        Resource = module.health_api.lambda_function_arn
      },
      {
        Action = [
          "logs:CreateLogGroup",
          "logs:DeleteLogGroup",
          "logs:PutRetentionPolicy",
          "logs:TagLogGroup",
          "logs:UntagLogGroup",
          "logs:ListTagsForResource",
        ]
        Effect   = "Allow"
        Resource = module.health_api.cloudwatch_log_group_arn
      },
      {
        Action = [
          "logs:DescribeLogGroups",
        ]
        Effect   = "Allow"
        Resource = "arn:aws:logs:${var.region}:${data.aws_caller_identity.current.account_id}:log-group:*"
      },
      {
        Action = [
          "apigateway:POST",
        ]
        Effect   = "Allow"
        Resource = "arn:aws:apigateway:${var.region}::/apis"
      },
      {
        Action = [
          "apigateway:GET",
          "apigateway:PUT",
          "apigateway:PATCH",
          "apigateway:DELETE",
        ]
        Effect = "Allow"
        Resource = [
          module.health_api.api_gateway_arn,
          "${module.health_api.api_gateway_arn}/*"
        ]
      },
      {
        Action = [
          "iam:GetRole",
          "iam:GetRolePolicy",
          "iam:ListRolePolicies",
          "iam:ListAttachedRolePolicies",
          "iam:CreateRole",
          "iam:DeleteRole",
          "iam:PassRole",
          "iam:UpdateRole",
          "iam:DeleteRolePolicy",
          "iam:PutRolePolicy",
          "iam:TagRole",
          "iam:UntagRole",
        ]
        Effect = "Allow"
        Resource = [
          module.health_api.lambda_role_arn,
          aws_iam_role.iam_role_github_action.arn
        ]
      },
      {
        Action = [
          "iam:GetOpenIDConnectProvider",
          "iam:CreateOpenIDConnectProvider",
          "iam:DeleteOpenIDConnectProvider",
          "iam:AddClientIDToOpenIDConnectProvider",
          "iam:RemoveClientIDFromOpenIDConnectProvider",
          "iam:UpdateOpenIDConnectProviderThumbprint",
          "iam:TagOpenIDConnectProvider",
          "iam:UntagOpenIDConnectProvider",
        ]
        Effect   = "Allow"
        Resource = aws_iam_openid_connect_provider.aws_iam_oidc_github_action.arn
      },
      {
        Action = [
          "s3:GetObject",
          "s3:PutObject",
        ]
        Effect   = "Allow"
        Resource = "arn:aws:s3:::3a43faa4-955a-4c3d-9579-af96f65a9932/env:/${var.environment}/terraform.tfstate"
      },
      {
        Action = [
          "s3:ListBucket",
        ]
        Effect   = "Allow"
        Resource = "arn:aws:s3:::3a43faa4-955a-4c3d-9579-af96f65a9932"
      },
    ]
  })
}