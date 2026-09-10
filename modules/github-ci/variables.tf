variable "environment" {
  type        = string
  description = "deployment environment"

  validation {
    condition     = contains(["staging", "prod"], var.environment)
    error_message = "Environment must be staging, or prod."
  }
}

variable "region" {
  type        = string
  description = "region name where the health-api stack is deployed"
}

variable "github_repo_condition" {
  type        = string
  description = "OIDC subject condition restricting which GitHub repo/branch can assume this role (format: repo:<org>/<repo>@<id>:ref:refs/heads/<branch>)"
}

variable "state_bucket" {
  type        = string
  description = "name of the S3 bucket holding the Terraform state (must match terraform.tf's backend block, which can't use a variable itself)"
}

variable "kms_key_arn" {
  type        = string
  description = "ARN of the health-api DynamoDB encryption KMS key"
}

variable "dynamodb_table_arn" {
  type        = string
  description = "ARN of the health-api DynamoDB table"
}

variable "lambda_function_arn" {
  type        = string
  description = "ARN of the health-api Lambda function"
}

variable "cloudwatch_log_group_arn" {
  type        = string
  description = "ARN of the health-api Lambda's CloudWatch log group"
}

variable "api_gateway_arn" {
  type        = string
  description = "ARN of the health-api API Gateway"
}

variable "lambda_role_arn" {
  type        = string
  description = "ARN of the health-api Lambda's execution IAM role"
}
