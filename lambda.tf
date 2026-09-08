
data "archive_file" "lambda_requests_files" {
  type        = "zip"
  source_file = "${path.module}/lambda/requests.py"
  output_path = "${path.module}/lambda/function.zip"
}

# Lambda function
resource "aws_lambda_function" "lambda_requests" {
  filename      = data.archive_file.lambda_requests_files.output_path
  function_name = "${var.environment}-lambda-requests"
  role          = aws_iam_role.iam_role_lambda_requests.arn
  handler       = "requests.handler" # Only for zipped
  code_sha256   = data.archive_file.lambda_requests_files.output_base64sha256

  runtime = "python3.14"

  environment {
    variables = {
      DATABASE      = aws_dynamodb_table.dynamodb.name,
      APP_LOG_LEVEL = var.app_log_level
    }
  }

  logging_config {
    log_format            = "JSON"
    application_log_level = var.app_log_level
    system_log_level      = var.system_log_level
  }

  depends_on = [
    aws_cloudwatch_log_group.cloudwatch_lambda_requests
  ]

  tags = {
    environment = var.environment
    application = "${var.environment}-lambda-requests"
  }
}
