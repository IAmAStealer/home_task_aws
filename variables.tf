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
