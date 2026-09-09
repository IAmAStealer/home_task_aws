#tfsec:ignore:aws-cloudwatch-log-group-customer-key -- deferred, see TODO.md (needs a logs.amazonaws.com statement added to the KMS key policy first)
resource "aws_cloudwatch_log_group" "cloudwatch_lambda_requests" {
  name              = "/aws/lambda/${var.environment}-lambda-requests"
  retention_in_days = var.log_retention_in_days
  tags = {
    environment = var.environment
    application = "lambda-requests"
  }
}