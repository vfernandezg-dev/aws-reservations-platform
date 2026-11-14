variable "name" {
  description = "Name prefix for all resources (<project>-<environment>)."
  type        = string
}

variable "subnet_ids" {
  description = "Isolated data subnets (at least two AZs)."
  type        = list(string)
}

variable "security_group_id" {
  description = "Security group attached to the instance."
  type        = string
}

variable "engine_version" {
  description = "RDS for PostgreSQL engine version."
  type        = string
  default     = "18.6"
}

variable "parameter_group_family" {
  description = "Parameter group family matching engine_version."
  type        = string
  default     = "postgres18"
}

variable "instance_class" {
  description = "Instance class. Graviton (db.t4g/db.m7g/db.r7g) is cheaper than x86 for the same size."
  type        = string
  default     = "db.t4g.micro"

  validation {
    condition     = startswith(var.instance_class, "db.")
    error_message = "instance_class must be an RDS instance class, e.g. db.t4g.micro."
  }
}

variable "allocated_storage" {
  description = "Initial gp3 storage in GiB."
  type        = number
  default     = 20

  validation {
    condition     = var.allocated_storage >= 20
    error_message = "gp3 storage for RDS PostgreSQL starts at 20 GiB."
  }
}

variable "max_allocated_storage" {
  description = "Upper limit for storage autoscaling in GiB (0 disables autoscaling)."
  type        = number
  default     = 100

  validation {
    condition     = var.max_allocated_storage == 0 || var.max_allocated_storage >= var.allocated_storage
    error_message = "max_allocated_storage must be 0 or at least allocated_storage."
  }
}

variable "multi_az" {
  description = "Run a synchronous standby in another AZ with automatic failover."
  type        = bool
  default     = false
}

variable "database_name" {
  description = "Name of the initial database."
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

variable "backup_retention_days" {
  description = "Days to keep automated backups (point-in-time recovery window)."
  type        = number
  default     = 7

  validation {
    condition     = var.backup_retention_days >= 1 && var.backup_retention_days <= 35
    error_message = "backup_retention_days must be between 1 and 35."
  }
}

variable "deletion_protection" {
  description = "Prevent the instance from being deleted (also keeps automated backups on deletion)."
  type        = bool
  default     = true
}

variable "skip_final_snapshot" {
  description = "Skip the final snapshot on deletion (only for disposable environments)."
  type        = bool
  default     = false
}

variable "performance_insights_enabled" {
  description = "Enable Performance Insights (7 days of retention, KMS-encrypted)."
  type        = bool
  default     = false
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

variable "log_retention_days" {
  description = "Retention of the exported database log groups in days."
  type        = number
  default     = 30
}
