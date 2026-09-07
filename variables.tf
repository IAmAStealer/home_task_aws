variable "environment" {
  type        = string
  description = "deployment environment"

  validation {
    condition = contains(["staging", "prod"], var.environment)
    error_message = "Environment must be staging, or prod."
  }
}