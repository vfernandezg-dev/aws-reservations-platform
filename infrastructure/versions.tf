terraform {
  # >= 1.10: S3 native state locking (use_lockfile), no DynamoDB table needed.
  # Cross-variable validation (>= 1.9) and mock providers in tests (>= 1.7)
  # are also used.
  required_version = ">= 1.10, < 2.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.70"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.7"
    }
    http = {
      source  = "hashicorp/http"
      version = "~> 3.5"
    }
  }
}
