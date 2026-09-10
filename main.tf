provider "aws" {
  region = var.region
}

module "health_api" {
  source                = "./modules/health-api"
  environment           = var.environment
  region                = var.region
  log_retention_in_days = var.log_retention_in_days
  app_log_level         = var.app_log_level
  system_log_level      = var.system_log_level
}

module "github_ci" {
  source                   = "./modules/github-ci"
  environment              = var.environment
  region                   = var.region
  github_repo_condition    = var.github_repo_condition
  state_bucket             = var.state_bucket
  kms_key_arn              = module.health_api.kms_key_arn
  dynamodb_table_arn       = module.health_api.dynamodb_table_arn
  lambda_function_arn      = module.health_api.lambda_function_arn
  cloudwatch_log_group_arn = module.health_api.cloudwatch_log_group_arn
  api_gateway_arn          = module.health_api.api_gateway_arn
  lambda_role_arn          = module.health_api.lambda_role_arn
}