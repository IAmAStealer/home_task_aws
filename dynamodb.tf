resource "aws_dynamodb_table" "dynamodb" {
  name         = "${var.environment}-requests-db"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "uuid"
  server_side_encryption {
    enabled     = true
    kms_key_arn = aws_kms_key.dynamodb_key.arn
  }

  attribute {
    name = "uuid"
    type = "S"
  }

  tags = {
    Name        = "${var.environment}-requests-db"
    Environment = var.environment
  }
}