variable "name" {
  description = "Name prefix for all resources (<project>-<environment>)."
  type        = string
}

variable "alarm_email" {
  description = "Email address subscribed to alarm notifications (confirmation required). Null disables the subscription."
  type        = string
  default     = null

  validation {
    condition     = var.alarm_email == null || can(regex("^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$", var.alarm_email))
    error_message = "alarm_email must be a valid email address or null."
  }
}

variable "alb_arn_suffix" {
  description = "ARN suffix of the internal ALB."
  type        = string
}

variable "target_group_arn_suffix" {
  description = "ARN suffix of the application target group."
  type        = string
}

variable "ecs_cluster_name" {
  description = "Name of the ECS cluster."
  type        = string
}

variable "ecs_service_name" {
  description = "Name of the ECS service."
  type        = string
}

variable "api_id" {
  description = "ID of the HTTP API."
  type        = string
}

variable "db_instance_identifier" {
  description = "Identifier of the RDS DB instance."
  type        = string
}

variable "cloudfront_distribution_id" {
  description = "ID of the CloudFront distribution."
  type        = string
}

variable "waf_web_acl_name" {
  description = "Name of the WAF Web ACL."
  type        = string
}

variable "waf_blocked_requests_threshold" {
  description = "Blocked requests per 5 minutes that trigger the WAF spike alarm."
  type        = number
  default     = 500
}

variable "kms_key_arn" {
  description = "Customer managed KMS key for the regional SNS topic (its policy must allow cloudwatch.amazonaws.com). Null leaves the topic unencrypted."
  type        = string
  default     = null
}

variable "global_kms_key_arn" {
  description = "Customer managed KMS key in us-east-1 for the global SNS topic. Null leaves the topic unencrypted."
  type        = string
  default     = null
}
