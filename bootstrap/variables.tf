variable "project_name" {
  description = "Project identifier; must match project_name of the infrastructure stack."
  type        = string
  default     = "reservations"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{2,15}$", var.project_name))
    error_message = "project_name must be 3-16 chars: lowercase letters, digits and hyphens."
  }
}

variable "aws_region" {
  description = "Region for the state bucket and ECR repository."
  type        = string
  default     = "us-east-1"
}

variable "github_repository" {
  description = "GitHub repository allowed to assume the CI roles, as \"owner/name\"."
  type        = string

  validation {
    condition     = can(regex("^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$", var.github_repository))
    error_message = "github_repository must look like \"owner/name\"."
  }
}

variable "environments" {
  description = "GitHub Environments allowed to assume the apply role."
  type        = list(string)
  default     = ["dev", "staging", "prod"]
}

variable "create_github_oidc_provider" {
  description = "Create the GitHub OIDC identity provider (set false if the account already has one)."
  type        = bool
  default     = true
}
