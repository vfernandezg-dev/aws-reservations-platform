variable "name" {
  description = "Name prefix for all resources (<project>-<environment>)."
  type        = string
}

variable "vpc_link_subnet_ids" {
  description = "Private subnets where the VPC Link ENIs are placed."
  type        = list(string)
}

variable "vpc_link_security_group_id" {
  description = "Security group attached to the VPC Link."
  type        = string
}

variable "alb_listener_arn" {
  description = "ARN of the internal ALB listener used as private integration target."
  type        = string
}

variable "enable_auth" {
  description = "Protect /api/{proxy+} with the Cognito JWT authorizer. /api/health and /api/public/* stay anonymous."
  type        = bool
  default     = true
}

variable "jwt_issuer" {
  description = "JWT issuer URL (https://cognito-idp.<region>.amazonaws.com/<user-pool-id>). Required when enable_auth is true."
  type        = string
  default     = null

  validation {
    condition     = !var.enable_auth || var.jwt_issuer != null
    error_message = "jwt_issuer is required when enable_auth is true."
  }
}

variable "jwt_audience" {
  description = "Accepted JWT audiences (Cognito app client IDs)."
  type        = list(string)
  default     = []

  validation {
    condition     = !var.enable_auth || length(var.jwt_audience) > 0
    error_message = "jwt_audience must contain at least one client ID when enable_auth is true."
  }
}

variable "throttling_rate_limit" {
  description = "Steady-state requests per second allowed for the stage."
  type        = number
  default     = 100
}

variable "throttling_burst_limit" {
  description = "Burst capacity for the stage."
  type        = number
  default     = 200
}

variable "log_retention_days" {
  description = "Retention of the access log group in days."
  type        = number
  default     = 30
}

variable "kms_key_arn" {
  description = "Customer managed KMS key for the access log group. Null uses CloudWatch default encryption."
  type        = string
  default     = null
}
