###############################################################################
# General
###############################################################################

variable "project_name" {
  description = "Short project identifier used as prefix for every resource name."
  type        = string
  default     = "reservations"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{2,15}$", var.project_name))
    error_message = "project_name must be 3-16 chars: lowercase letters, digits and hyphens, starting with a letter."
  }
}

variable "environment" {
  description = "Deployment environment."
  type        = string

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be one of: dev, staging, prod."
  }
}

variable "aws_region" {
  description = "Primary AWS region. Edge resources (CloudFront, WAF) are always in us-east-1."
  type        = string
  default     = "us-east-1"
}

variable "owner" {
  description = "Team or person accountable for the resources (Owner tag)."
  type        = string
  default     = "platform-team"
}

variable "cost_center" {
  description = "Cost allocation tag value (CostCenter tag)."
  type        = string
  default     = "portfolio"
}

variable "repository" {
  description = "Source repository of this code (Repository tag)."
  type        = string
  default     = "aws-reservations-platform"
}

variable "deletion_protection" {
  description = "Enable deletion protection on stateful resources (RDS, Cognito, ALB) and keep data on destroy."
  type        = bool
  default     = true
}

variable "log_retention_days" {
  description = "Retention in days for CloudWatch log groups and S3 access logs."
  type        = number
  default     = 30

  validation {
    condition     = contains([1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1096, 1827, 2192, 2557, 2922, 3288, 3653], var.log_retention_days)
    error_message = "log_retention_days must be a value supported by CloudWatch Logs (e.g. 7, 14, 30, 90, 365)."
  }
}

variable "alarm_email" {
  description = "Optional email address for CloudWatch alarm notifications."
  type        = string
  default     = null
}

###############################################################################
# Network
###############################################################################

variable "vpc_cidr" {
  description = "IPv4 /16 CIDR block of the VPC."
  type        = string
  default     = "10.20.0.0/16"
}

variable "az_count" {
  description = "Number of Availability Zones to use (2 or 3)."
  type        = number
  default     = 2

  validation {
    condition     = var.az_count >= 2 && var.az_count <= 3
    error_message = "az_count must be 2 or 3."
  }
}

variable "single_nat_gateway" {
  description = "Share one NAT gateway across AZs (cost saving for non-production)."
  type        = bool
  default     = false
}

variable "interface_endpoint_services" {
  description = "Interface VPC endpoints to create, e.g. [\"ecr.api\", \"ecr.dkr\", \"logs\", \"secretsmanager\"]."
  type        = list(string)
  default     = []
}

###############################################################################
# Edge: CloudFront + WAF
###############################################################################

variable "cloudfront_price_class" {
  description = "CloudFront price class."
  type        = string
  default     = "PriceClass_100"
}

variable "waf_rate_limit_per_5_minutes" {
  description = "Requests allowed per client IP in 5 minutes before WAF blocks it."
  type        = number
  default     = 2000
}

variable "waf_blocked_country_codes" {
  description = "Countries (ISO alpha-2) blocked at the edge."
  type        = list(string)
  default     = []
}

###############################################################################
# API + authentication
###############################################################################

variable "enable_auth" {
  description = "Require a Cognito JWT on /api/{proxy+} (public and health routes stay open)."
  type        = bool
  default     = true
}

variable "enable_hosted_ui" {
  description = "Enable Cognito Managed Login with the CloudFront URL as OAuth callback."
  type        = bool
  default     = false
}

variable "cognito_mfa" {
  description = "Cognito MFA mode: OFF, OPTIONAL or ON."
  type        = string
  default     = "OPTIONAL"
}

variable "api_throttling_rate_limit" {
  description = "API Gateway steady-state requests per second."
  type        = number
  default     = 100
}

variable "api_throttling_burst_limit" {
  description = "API Gateway burst capacity."
  type        = number
  default     = 200
}

###############################################################################
# Application (ECS Fargate)
###############################################################################

variable "ecr_repository_name" {
  description = "Name of the ECR repository created by the bootstrap stack."
  type        = string
  default     = "reservations-app"
}

variable "app_image_tag" {
  description = "Immutable image tag to deploy (git commit SHA produced by the app pipeline)."
  type        = string

  validation {
    condition     = can(regex("^[A-Za-z0-9._-]{1,128}$", var.app_image_tag)) && var.app_image_tag != "latest"
    error_message = "app_image_tag must be a valid, immutable tag (not \"latest\")."
  }
}

variable "app_cpu" {
  description = "Fargate task CPU units."
  type        = number
  default     = 256
}

variable "app_memory" {
  description = "Fargate task memory (MiB)."
  type        = number
  default     = 512
}

variable "app_min_capacity" {
  description = "Minimum number of tasks."
  type        = number
  default     = 1
}

variable "app_max_capacity" {
  description = "Maximum number of tasks."
  type        = number
  default     = 2
}

variable "use_fargate_spot" {
  description = "Run tasks on Fargate Spot."
  type        = bool
  default     = false
}

###############################################################################
# Database (RDS for PostgreSQL)
###############################################################################

variable "db_instance_class" {
  description = "RDS instance class (Graviton db.t4g.* recommended)."
  type        = string
  default     = "db.t4g.micro"
}

variable "db_allocated_storage" {
  description = "Initial gp3 storage in GiB."
  type        = number
  default     = 20
}

variable "db_max_allocated_storage" {
  description = "Storage autoscaling limit in GiB (0 disables autoscaling)."
  type        = number
  default     = 100
}

variable "db_multi_az" {
  description = "Synchronous standby in a second AZ with automatic failover."
  type        = bool
  default     = false
}

variable "db_backup_retention_days" {
  description = "Automated backup retention in days."
  type        = number
  default     = 7
}

variable "db_enhanced_monitoring_interval" {
  description = "Enhanced Monitoring interval in seconds (0 disables it)."
  type        = number
  default     = 0
}

variable "db_performance_insights" {
  description = "Enable Performance Insights."
  type        = bool
  default     = false
}
