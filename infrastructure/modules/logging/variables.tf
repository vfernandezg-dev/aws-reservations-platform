variable "name" {
  description = "Name prefix for all resources (<project>-<environment>)."
  type        = string
}

variable "retention_days" {
  description = "Days to keep log objects before they expire."
  type        = number
  default     = 90

  validation {
    condition     = var.retention_days >= 1
    error_message = "retention_days must be at least 1."
  }
}

variable "alb_prefix" {
  description = "Key prefix used for Application Load Balancer access logs."
  type        = string
  default     = "alb"
}

variable "force_destroy" {
  description = "Allow Terraform to delete the bucket even if it still contains logs (use only in ephemeral environments)."
  type        = bool
  default     = false
}
