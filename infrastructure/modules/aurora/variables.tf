variable "name" {
  description = "Name prefix for all resources (<project>-<environment>)."
  type        = string
}

variable "subnet_ids" {
  description = "Isolated data subnets (at least two AZs)."
  type        = list(string)
}

variable "security_group_id" {
  description = "Security group attached to the cluster."
  type        = string
}

variable "engine_version" {
  description = "Aurora PostgreSQL engine version (must support Serverless v2 scale to zero)."
  type        = string
  default     = "18.6"
}

variable "parameter_group_family" {
  description = "Cluster parameter group family matching engine_version."
  type        = string
  default     = "aurora-postgresql18"
}

variable "database_name" {
  description = "Name of the initial database (schema)."
  type        = string
  default     = "reservations"
}

variable "master_username" {
  description = "Master user name. The password is managed by RDS in Secrets Manager."
  type        = string
  default     = "app_admin"
}

variable "port" {
  description = "Database port."
  type        = number
  default     = 5432
}

variable "min_capacity" {
  description = "Minimum Aurora Capacity Units. 0 enables scale-to-zero (auto-pause) for idle environments."
  type        = number
  default     = 0.5

  validation {
    condition     = var.min_capacity >= 0 && var.min_capacity <= 256
    error_message = "min_capacity must be between 0 and 256 ACUs."
  }
}

variable "max_capacity" {
  description = "Maximum Aurora Capacity Units."
  type        = number
  default     = 4

  validation {
    condition     = var.max_capacity >= 1 && var.max_capacity >= var.min_capacity
    error_message = "max_capacity must be at least 1 and not lower than min_capacity."
  }
}

variable "seconds_until_auto_pause" {
  description = "Idle seconds before the cluster pauses (only when min_capacity = 0)."
  type        = number
  default     = 300

  validation {
    condition     = var.seconds_until_auto_pause >= 300 && var.seconds_until_auto_pause <= 86400
    error_message = "seconds_until_auto_pause must be between 300 and 86400."
  }
}

variable "instance_count" {
  description = "Number of db.serverless instances: 1 = writer only, 2+ = writer plus reader(s) for Multi-AZ failover."
  type        = number
  default     = 1

  validation {
    condition     = var.instance_count >= 1 && var.instance_count <= 3
    error_message = "instance_count must be between 1 and 3."
  }
}

variable "backup_retention_days" {
  description = "Days to keep automated backups."
  type        = number
  default     = 7

  validation {
    condition     = var.backup_retention_days >= 1 && var.backup_retention_days <= 35
    error_message = "backup_retention_days must be between 1 and 35."
  }
}

variable "deletion_protection" {
  description = "Prevent the cluster from being deleted."
  type        = bool
  default     = true
}

variable "skip_final_snapshot" {
  description = "Skip the final snapshot on deletion (only for disposable environments)."
  type        = bool
  default     = false
}

variable "performance_insights_enabled" {
  description = "Enable Performance Insights on the instances."
  type        = bool
  default     = false
}

variable "log_retention_days" {
  description = "Retention of the exported database log groups in days."
  type        = number
  default     = 30
}

variable "enhanced_monitoring_interval" {
  description = "Enhanced Monitoring granularity in seconds (0 disables it)."
  type        = number
  default     = 0

  validation {
    condition     = contains([0, 1, 5, 10, 15, 30, 60], var.enhanced_monitoring_interval)
    error_message = "enhanced_monitoring_interval must be one of 0, 1, 5, 10, 15, 30, 60."
  }
}

variable "kms_key_arn" {
  description = "Customer managed KMS key for storage, Performance Insights, the master secret and log groups. Null uses AWS managed keys."
  type        = string
  default     = null
}
