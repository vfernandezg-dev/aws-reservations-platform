variable "name" {
  description = "Name prefix for all resources (<project>-<environment>)."
  type        = string
}

variable "static_bucket_id" {
  description = "Name of the S3 bucket with static content."
  type        = string
}

variable "static_bucket_arn" {
  description = "ARN of the S3 bucket with static content."
  type        = string
}

variable "static_bucket_regional_domain_name" {
  description = "Regional domain name of the static content bucket."
  type        = string
}

variable "api_endpoint" {
  description = "Invoke URL of the API Gateway HTTP API (https://<id>.execute-api.<region>.amazonaws.com)."
  type        = string

  validation {
    condition     = startswith(var.api_endpoint, "https://")
    error_message = "api_endpoint must start with https://."
  }
}

variable "origin_verify_header_name" {
  description = "Name of the secret header CloudFront adds to API requests."
  type        = string
  default     = "X-Origin-Verify"
}

variable "origin_verify_secret" {
  description = "Value of the secret origin header (validated by the internal ALB)."
  type        = string
  sensitive   = true
}

variable "web_acl_arn" {
  description = "ARN of the WAFv2 Web ACL (CLOUDFRONT scope) to attach."
  type        = string
}

variable "price_class" {
  description = "CloudFront price class: PriceClass_100, PriceClass_200 or PriceClass_All."
  type        = string
  default     = "PriceClass_100"

  validation {
    condition     = contains(["PriceClass_100", "PriceClass_200", "PriceClass_All"], var.price_class)
    error_message = "price_class must be PriceClass_100, PriceClass_200 or PriceClass_All."
  }
}

variable "enable_access_logs" {
  description = "Deliver CloudFront standard logs (v2) to log_bucket_arn. A separate flag keeps `count` known at plan time."
  type        = bool
  default     = true
}

variable "log_bucket_arn" {
  description = "ARN of the S3 bucket for CloudFront standard logs (required when enable_access_logs is true)."
  type        = string
  default     = null

  validation {
    condition     = !var.enable_access_logs || var.log_bucket_arn != null
    error_message = "log_bucket_arn is required when enable_access_logs is true."
  }
}

variable "aliases" {
  description = "Optional custom domain names (CNAMEs). Requires acm_certificate_arn."
  type        = list(string)
  default     = []

  validation {
    condition     = length(var.aliases) == 0 || var.acm_certificate_arn != null
    error_message = "Custom domain aliases require acm_certificate_arn."
  }
}

variable "acm_certificate_arn" {
  description = "Optional ACM certificate ARN in us-east-1 for the custom domain names."
  type        = string
  default     = null

  validation {
    condition     = var.acm_certificate_arn == null || can(regex("^arn:aws:acm:us-east-1:", var.acm_certificate_arn))
    error_message = "CloudFront certificates must be issued by ACM in us-east-1."
  }
}
