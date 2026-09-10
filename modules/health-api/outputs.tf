output "kms_key_arn" {
  description = "dynamodb encryption key arn"
  value       = aws_kms_key.dynamodb_key.arn
}

output "dynamodb_table_arn" {
  description = "dynamodb table arn"
  value       = aws_dynamodb_table.dynamodb.arn
}

output "lambda_function_arn" {
  description = "lambda function arn"
  value       = aws_lambda_function.lambda_requests.arn
}

output "cloudwatch_log_group_arn" {
  description = "cloudwatch log group arn"
  value       = aws_cloudwatch_log_group.cloudwatch_lambda_requests.arn
}

output "api_gateway_arn" {
  description = "api gateway v2 arn"
  value       = aws_apigatewayv2_api.api_gateway_lambda.arn
}

output "lambda_role_arn" {
  description = "lambda iam role arn"
  value       = aws_iam_role.iam_role_lambda_requests.arn
}

output "invoke_url" {
  description = "health-api URL"
  value       = aws_apigatewayv2_stage.api_gateway_lambda_stage.invoke_url
}
