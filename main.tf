provider "aws" {
  region = var.region
}

data "aws_caller_identity" "current" {}

module "health_api" {
  source                = "./modules/health-api"
  environment           = var.environment
  region                = var.region
  log_retention_in_days = var.log_retention_in_days
  app_log_level         = var.app_log_level
  system_log_level      = var.system_log_level
}