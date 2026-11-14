variable "name" {
  description = "Name prefix for all resources (<project>-<environment>). Max 28 characters (ALB/TG name limits)."
  type        = string

  validation {
    condition     = length(var.name) <= 28
    error_message = "name must be at most 28 characters so \"<name>-app\" fits the 32-character target group limit."
  }
}

variable "vpc_id" {
  description = "ID of the VPC."
  type        = string
}

variable "subnet_ids" {
  description = "Private application subnets for the internal ALB (at least two AZs)."
  type        = list(string)
}

variable "security_group_id" {
  description = "Security group attached to the ALB."
  type        = string
}

variable "target_port" {
  description = "Port the ECS tasks listen on."
  type        = number
  default     = 8080
}

variable "health_check_path" {
  description = "HTTP path used by target group health checks (must not depend on the database)."
  type        = string
  default     = "/health"
}

variable "origin_verify_header_name" {
  description = "Name of the secret header that must be present for requests to be forwarded."
  type        = string
  default     = "X-Origin-Verify"
}

variable "origin_verify_secret" {
  description = "Expected value of the secret header (alphanumeric, max 128 characters: ALB treats * and ? as wildcards)."
  type        = string
  sensitive   = true

  validation {
    condition     = can(regex("^[A-Za-z0-9]{32,128}$", var.origin_verify_secret))
    error_message = "origin_verify_secret must be 32-128 alphanumeric characters."
  }
}

variable "access_logs_bucket" {
  description = "S3 bucket for ALB access logs. Null disables access logs."
  type        = string
  default     = null
}

variable "access_logs_prefix" {
  description = "Key prefix for ALB access logs."
  type        = string
  default     = "alb"
}

variable "deletion_protection" {
  description = "Enable ALB deletion protection."
  type        = bool
  default     = false
}
