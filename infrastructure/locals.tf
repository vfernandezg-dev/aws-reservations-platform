locals {
  name = "${var.project_name}-${var.environment}"
  azs  = slice(sort(data.aws_availability_zones.available.names), 0, var.az_count)

  default_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
    Repository  = var.repository
    Owner       = var.owner
    CostCenter  = var.cost_center
  }

  app_port      = 8080
  db_port       = 5432
  app_image     = "${data.aws_ecr_repository.app.repository_url}:${var.app_image_tag}"
  origin_header = "X-Origin-Verify"
}
