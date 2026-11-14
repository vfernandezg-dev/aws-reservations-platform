variable "name" {
  description = "Name prefix for all resources (<project>-<environment>)."
  type        = string
}

variable "image" {
  description = "Full container image URI including tag, e.g. <account>.dkr.ecr.<region>.amazonaws.com/reservations-app:<git-sha>."
  type        = string
}

variable "image_tag" {
  description = "Image tag, exposed to the app as APP_VERSION."
  type        = string
}

variable "container_port" {
  description = "Port the container listens on."
  type        = number
  default     = 8080
}

variable "cpu" {
  description = "Task CPU units (256 = 0.25 vCPU)."
  type        = number
  default     = 256

  validation {
    condition     = contains([256, 512, 1024, 2048, 4096], var.cpu)
    error_message = "cpu must be one of 256, 512, 1024, 2048, 4096."
  }
}

variable "memory" {
  description = "Task memory in MiB (must be a valid Fargate combination with cpu)."
  type        = number
  default     = 512
}

variable "subnet_ids" {
  description = "Private application subnets for the tasks."
  type        = list(string)
}

variable "security_group_id" {
  description = "Security group attached to the tasks."
  type        = string
}

variable "target_group_arn" {
  description = "ALB target group the service registers into."
  type        = string
}

variable "alb_arn_suffix" {
  description = "ALB ARN suffix (for the request-count scaling metric)."
  type        = string
}

variable "target_group_arn_suffix" {
  description = "Target group ARN suffix (for the request-count scaling metric)."
  type        = string
}

variable "min_capacity" {
  description = "Minimum number of running tasks (also the initial desired count)."
  type        = number
  default     = 1
}

variable "max_capacity" {
  description = "Maximum number of running tasks."
  type        = number
  default     = 2

  validation {
    condition     = var.max_capacity >= var.min_capacity
    error_message = "max_capacity must be greater than or equal to min_capacity."
  }
}

variable "cpu_target_percent" {
  description = "Target average CPU utilization for scaling."
  type        = number
  default     = 60
}

variable "requests_per_target" {
  description = "Target ALB requests per task per minute for scaling."
  type        = number
  default     = 500
}

variable "use_fargate_spot" {
  description = "Run tasks on Fargate Spot (up to ~70% cheaper, can be interrupted). Recommended for non-production."
  type        = bool
  default     = false
}

variable "db_host" {
  description = "Aurora writer endpoint."
  type        = string
}

variable "db_port" {
  description = "Aurora port."
  type        = number
  default     = 5432
}

variable "db_name" {
  description = "Database (schema) name."
  type        = string
}

variable "db_secret_arn" {
  description = "ARN of the Secrets Manager secret holding the database credentials (Aurora-managed)."
  type        = string
}

variable "environment" {
  description = "Extra non-secret environment variables for the container."
  type        = map(string)
  default     = {}
}

variable "log_retention_days" {
  description = "Retention of the container log group in days."
  type        = number
  default     = 30
}

variable "wait_for_steady_state" {
  description = "Make terraform apply wait until the service is stable (healthy tasks behind the ALB)."
  type        = bool
  default     = true
}

variable "kms_key_arn" {
  description = "Customer managed KMS key encrypting the log group and the database secret. Null uses AWS managed keys."
  type        = string
  default     = null
}
