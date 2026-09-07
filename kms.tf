resource "aws_kms_key" "dynamodb_key" {
  description             = "${var.environment}-lambda-requests-db-key"
  enable_key_rotation     = true
  deletion_window_in_days = 20
  policy = jsonencode({
    Version = "2012-10-17"
    Id      = "key-dynamodb-1"
    Statement = [
      {
        Sid    = "Enable IAM User Permissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        },
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "Allow administration of the key"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:user/terraform-debian-local-alexis"
        },
        Action = [
          "kms:ReplicateKey",
          "kms:Create*",
          "kms:Describe*",
          "kms:Enable*",
          "kms:List*",
          "kms:Put*",
          "kms:Update*",
          "kms:Revoke*",
          "kms:Disable*",
          "kms:Get*",
          "kms:Delete*",
          "kms:ScheduleKeyDeletion",
          "kms:CancelKeyDeletion"
        ],
        Resource = "*"
      }
      # Waiting for Lambda role
      # {
      #   Sid    = "Allow use of the key"
      #   Effect = "Allow"
      #   Principal = {
      #     AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:user/Bob"
      #   },
      #   Action = [
      #     "kms:DescribeKey",
      #     "kms:Encrypt",
      #     "kms:Decrypt",
      #     "kms:ReEncrypt*",
      #     "kms:GenerateDataKey",
      #     "kms:GenerateDataKeyWithoutPlaintext"
      #   ],
      #   Resource = "*"
      # }
    ]
  })
  tags = {
    environment = var.environment
    application = "lambda-requests"
  }
}

resource "aws_kms_alias" "dynamodb_key" {
  name          = "alias/${var.environment}-requests-db-key"
  target_key_id = aws_kms_key.dynamodb_key.key_id
}
