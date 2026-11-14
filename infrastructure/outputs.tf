output "cloudfront_url" {
  description = "Public entry point of the platform (static site + /api/*)."
  value       = module.cdn.url
}

output "cloudfront_distribution_id" {
  description = "CloudFront distribution ID (cache invalidations)."
  value       = module.cdn.distribution_id
}

output "api_endpoint" {
  description = "Raw HTTP API endpoint. Direct calls are rejected by the ALB; use cloudfront_url."
  value       = module.api.api_endpoint
}

output "cognito_user_pool_id" {
  description = "Cognito user pool ID."
  value       = module.auth.user_pool_id
}

output "cognito_client_id" {
  description = "Cognito SPA app client ID."
  value       = module.auth.client_id
}

output "cognito_hosted_ui_url" {
  description = "Base URL of the Cognito Managed Login pages."
  value       = module.auth.hosted_ui_url
}

output "db_address" {
  description = "PostgreSQL hostname (reachable only from the application subnets)."
  value       = module.database.address
}

output "db_secret_arn" {
  description = "Secrets Manager ARN of the RDS-managed database credentials."
  value       = module.database.master_user_secret_arn
}

output "ecs_cluster_name" {
  description = "ECS cluster name."
  value       = module.ecs.cluster_name
}

output "ecs_service_name" {
  description = "ECS service name."
  value       = module.ecs.service_name
}

output "migration_task_definition_arn" {
  description = "Task definition used by scripts/db-migrate.sh."
  value       = module.ecs.migration_task_definition_arn
}

output "app_subnet_ids" {
  description = "Private application subnets (used to run one-off tasks)."
  value       = module.network.app_subnet_ids
}

output "app_security_group_id" {
  description = "Security group of the application tasks (used to run one-off tasks)."
  value       = module.security.app_security_group_id
}

output "dashboard_url" {
  description = "CloudWatch dashboard for the environment."
  value       = "https://${var.aws_region}.console.aws.amazon.com/cloudwatch/home?region=${var.aws_region}#dashboards:name=${module.monitoring.dashboard_name}"
}

output "environment" {
  description = "Environment this state belongs to (used by scripts as a safety check)."
  value       = var.environment
}

output "ecs_log_group_name" {
  description = "CloudWatch log group of the application containers."
  value       = module.ecs.log_group_name
}

output "app_image_tag" {
  description = "Image tag currently deployed (CI plans reuse it unless a new tag is given)."
  value       = var.app_image_tag
}
