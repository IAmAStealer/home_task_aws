resource "aws_apigatewayv2_api" "api_gateway_lambda" {
  name          = "${var.environment}-lambda-api-gateway"
  protocol_type = "HTTP"
}

resource "aws_apigatewayv2_integration" "api_gateway_integration_lambda" {
  api_id           = aws_apigatewayv2_api.api_gateway_lambda.id
  integration_type = "AWS_PROXY"

  connection_type           = "INTERNET"
  content_handling_strategy = "CONVERT_TO_TEXT"
  description               = "Lambda requests"
  integration_method        = "POST"
  integration_uri           = aws_lambda_function.lambda_requests.invoke_arn
  passthrough_behavior      = "WHEN_NO_MATCH"
}

resource "aws_apigatewayv2_stage" "api_gateway_lambda_stage" {
  api_id      = aws_apigatewayv2_api.api_gateway_lambda.id
  name        = "$default"
  auto_deploy = true # Even in production > CI/CD Will cover manual deployment of code in prod

  default_route_settings {
    throttling_burst_limit = 5
    throttling_rate_limit  = 5
  }
}

resource "aws_apigatewayv2_route" "api_gateway_lambda_route" {
  api_id    = aws_apigatewayv2_api.api_gateway_lambda.id
  for_each  = toset(["GET /health", "POST /health"])
  route_key = each.key
  target    = "integrations/${aws_apigatewayv2_integration.api_gateway_integration_lambda.id}"
}

resource "aws_lambda_permission" "api_gateway_lambda_permission" {
  for_each      = toset(["GET", "POST"])
  statement_id  = "allow-api-gateway-lambda-${lower(each.key)}"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.lambda_requests.function_name
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_apigatewayv2_api.api_gateway_lambda.execution_arn}/$default/${each.key}/health"
}
