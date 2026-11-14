variable "name" {
  description = "Name prefix for all resources (<project>-<environment>)."
  type        = string
}

variable "deletion_protection" {
  description = "Protect the user pool from deletion."
  type        = bool
  default     = true
}

variable "mfa_configuration" {
  description = "MFA enforcement: OFF, OPTIONAL (users may enrol TOTP) or ON (required)."
  type        = string
  default     = "OPTIONAL"

  validation {
    condition     = contains(["OFF", "OPTIONAL", "ON"], var.mfa_configuration)
    error_message = "mfa_configuration must be OFF, OPTIONAL or ON."
  }
}

variable "password_minimum_length" {
  description = "Minimum password length."
  type        = number
  default     = 12

  validation {
    condition     = var.password_minimum_length >= 8 && var.password_minimum_length <= 99
    error_message = "password_minimum_length must be between 8 and 99."
  }
}

variable "allow_self_registration" {
  description = "Allow users to sign themselves up. When false, only administrators can create users."
  type        = bool
  default     = true
}

variable "access_token_validity_minutes" {
  description = "Lifetime of access and ID tokens in minutes."
  type        = number
  default     = 60

  validation {
    condition     = var.access_token_validity_minutes >= 5 && var.access_token_validity_minutes <= 1440
    error_message = "Token validity must be between 5 and 1440 minutes."
  }
}

variable "refresh_token_validity_days" {
  description = "Lifetime of refresh tokens in days."
  type        = number
  default     = 30
}

variable "callback_urls" {
  description = "OAuth callback URLs for the Managed Login (hosted UI). Empty list disables the OAuth code flow."
  type        = list(string)
  default     = []

  validation {
    condition     = alltrue([for u in var.callback_urls : startswith(u, "https://") || startswith(u, "http://localhost")])
    error_message = "Callback URLs must use https:// (http://localhost is allowed for local development)."
  }
}

variable "logout_urls" {
  description = "Allowed sign-out redirect URLs."
  type        = list(string)
  default     = []
}
