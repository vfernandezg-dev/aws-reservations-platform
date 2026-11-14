variable "name" {
  description = "Name prefix for all resources (<project>-<environment>)."
  type        = string
}

variable "cidr_block" {
  description = "IPv4 CIDR block of the VPC. Must be a /16 so the /24 subnet layout fits."
  type        = string

  validation {
    condition     = can(cidrhost(var.cidr_block, 0)) && endswith(var.cidr_block, "/16")
    error_message = "cidr_block must be a valid IPv4 /16 CIDR, e.g. 10.20.0.0/16."
  }
}

variable "azs" {
  description = "Availability Zones to spread subnets across (2 or 3)."
  type        = list(string)

  validation {
    condition     = length(var.azs) >= 2 && length(var.azs) <= 3
    error_message = "Provide 2 or 3 Availability Zones."
  }
}

variable "single_nat_gateway" {
  description = "Use one shared NAT gateway instead of one per AZ (cheaper, not AZ-resilient)."
  type        = bool
  default     = false
}

variable "interface_endpoint_services" {
  description = "AWS service names for interface VPC endpoints, e.g. [\"ecr.api\", \"ecr.dkr\", \"logs\", \"secretsmanager\"]. Empty list disables them."
  type        = list(string)
  default     = []
}

variable "enable_flow_logs" {
  description = "Deliver VPC Flow Logs to flow_logs_bucket_arn. A separate flag keeps `count` known at plan time."
  type        = bool
  default     = true
}

variable "flow_logs_bucket_arn" {
  description = "ARN of the S3 bucket that receives VPC Flow Logs (required when enable_flow_logs is true)."
  type        = string
  default     = null

  validation {
    condition     = !var.enable_flow_logs || var.flow_logs_bucket_arn != null
    error_message = "flow_logs_bucket_arn is required when enable_flow_logs is true."
  }
}
