resource "aws_dynamodb_table" "dynamodb" {
  name         = "${var.environment}-lambda-requests-db"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "uuid"
  server_side_encryption {
    enabled     = true
    kms_key_arn = aws_kms_key.dynamodb_key.arn
  }

  point_in_time_recovery {
    enabled = true
  }

  attribute {
    name = "uuid"
    type = "S"
  }

  tags = {
    environment = var.environment
    application = "lambda-requests"
  }
}