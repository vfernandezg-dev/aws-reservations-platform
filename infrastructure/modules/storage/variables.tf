variable "name" {
  description = "Name prefix for all resources (<project>-<environment>)."
  type        = string
}

variable "environment" {
  description = "Environment name, shown on the sample site."
  type        = string
}

variable "site_title" {
  description = "Title rendered on the sample site."
  type        = string
  default     = "Reservations Platform"
}

variable "upload_sample_site" {
  description = "Upload the bundled sample static site (index.html calls the API through CloudFront)."
  type        = bool
  default     = true
}

variable "noncurrent_version_retention_days" {
  description = "Days to keep previous object versions."
  type        = number
  default     = 30
}

variable "force_destroy" {
  description = "Allow Terraform to delete the bucket even if it is not empty."
  type        = bool
  default     = false
}
