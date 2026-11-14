provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = "shared"
      ManagedBy   = "terraform"
      Stack       = "bootstrap"
      Repository  = var.github_repository
    }
  }
}
