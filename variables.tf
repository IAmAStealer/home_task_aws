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
  description = "region name where to deploy"
  default     = "eu-north-1" # closer to users
}

variable "log_retention_in_days" {
  type        = number
  description = "number of days to keep logs for the app"
}

variable "app_log_level" {
  description = "application log level"
  type        = string
  validation {
    condition     = contains(["TRACE", "DEBUG", "INFO", "WARN", "ERROR", "FATAL"], var.app_log_level)
    error_message = "app_log_level must be TRACE, DEBUG, INFO, WARN, ERROR, FATAL."
  }
}

variable "system_log_level" {
  description = "system log level"
  type        = string
  validation {
    condition     = contains(["DEBUG", "INFO", "WARN"], var.system_log_level)
    error_message = "system_log_level must be DEBUG, INFO, WARN."
  }
}

variable "github_repo_condition" {
  type        = string
  description = "OIDC subject condition restricting which GitHub repo/branch can assume the deploy role"
}

variable "state_bucket" {
  type        = string
  description = "name of the S3 bucket holding the Terraform state (must match terraform.tf's backend block, which can't use a variable itself)"
}
