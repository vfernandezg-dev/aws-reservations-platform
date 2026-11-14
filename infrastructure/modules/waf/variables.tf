variable "name" {
  description = "Name prefix for all resources (<project>-<environment>)."
  type        = string
}

variable "rate_limit_per_5_minutes" {
  description = "Maximum requests a single IP may send in a 5-minute window before it is blocked."
  type        = number
  default     = 2000

  validation {
    condition     = var.rate_limit_per_5_minutes >= 100
    error_message = "AWS WAF requires a rate limit of at least 100."
  }
}

variable "blocked_country_codes" {
  description = "ISO 3166-1 alpha-2 country codes to block at the edge. Empty list disables geo blocking."
  type        = list(string)
  default     = []

  validation {
    condition     = alltrue([for c in var.blocked_country_codes : can(regex("^[A-Z]{2}$", c))])
    error_message = "Country codes must be two upper-case letters, e.g. \"KP\"."
  }
}

variable "enable_logging" {
  description = "Send WAF logs (with Authorization/Cookie headers redacted) to CloudWatch Logs."
  type        = bool
  default     = true
}

variable "log_retention_days" {
  description = "Retention of the WAF log group in days."
  type        = number
  default     = 30
}

variable "kms_key_arn" {
  description = "Customer managed KMS key in us-east-1 for the WAF log group. Null uses CloudWatch default encryption."
  type        = string
  default     = null
}
