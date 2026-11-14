variable "name" {
  description = "Name prefix for all resources (<project>-<environment>)."
  type        = string
}

variable "vpc_id" {
  description = "ID of the VPC the security groups belong to."
  type        = string
}

variable "app_port" {
  description = "Port the application container listens on."
  type        = number
  default     = 8080
}

variable "db_port" {
  description = "Port of the database engine."
  type        = number
  default     = 3306
}
