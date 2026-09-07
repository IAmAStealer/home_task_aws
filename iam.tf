
resource "aws_iam_role" "iam_role_lambda_requests" {
  name        = "${var.environment}-iam-role-lambda-requests"
  description = "IAM role for lambda requests"
  # Terraform's "jsonencode" function converts a
  # Terraform expression result to valid JSON syntax.
  assume_role_policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Sid" : "Statement1",
        "Effect" : "Allow",
        "Principal" : {
          "Service" : "lambda.amazonaws.com"
        },
        "Action" : "sts:AssumeRole"
      }
    ]
  })

  tags = {
    environment = var.environment
    application = "lambda-requests"
  }
}

resource "aws_iam_role_policy" "iam_role_policy_lambda_requests" {
  name = "${var.environment}-iam-role-policy-lambda-requests"
  role = aws_iam_role.iam_role_lambda_requests.id
  # Terraform's "jsonencode" function converts a
  # Terraform expression result to valid JSON syntax.
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "dynamodb:PutItem",
        ]
        Effect   = "Allow"
        Resource = aws_dynamodb_table.dynamodb.arn
      },
      # {
      #   Action = [
      #     "logs:CreateLogGroup",
      #     "logs:CreateLogStream",
      #     "logs:PutLogEvents"
      #   ]
      #   Effect   = "Allow"
      #   Resource = cloudwatch.arn
      # },
      {
        Action = [
          "kms:GenerateDataKey",
          "kms:Decrypt",
          "kms:DescribeKey"
        ]
        Effect   = "Allow"
        Resource = aws_kms_key.dynamodb_key.arn
      }
    ]
  })
}