variable "name" {
  description = "Name of the key alias (alias/<name>)."
  type        = string
}

variable "region" {
  description = "Region for the key. Null uses the provider region; edge resources need a key in us-east-1."
  type        = string
  default     = null
}

variable "deletion_window_in_days" {
  description = "Waiting period before a scheduled key deletion completes."
  type        = number
  default     = 30

  validation {
    condition     = var.deletion_window_in_days >= 7 && var.deletion_window_in_days <= 30
    error_message = "deletion_window_in_days must be between 7 and 30."
  }
}
