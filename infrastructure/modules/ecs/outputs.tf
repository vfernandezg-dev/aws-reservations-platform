output "cluster_name" {
  description = "Name of the ECS cluster."
  value       = aws_ecs_cluster.this.name
}

output "cluster_arn" {
  description = "ARN of the ECS cluster."
  value       = aws_ecs_cluster.this.arn
}

output "service_name" {
  description = "Name of the ECS service."
  value       = aws_ecs_service.app.name
}

output "task_definition_arn" {
  description = "ARN of the application task definition revision."
  value       = aws_ecs_task_definition.app.arn
}

output "migration_task_definition_arn" {
  description = "ARN of the one-off database migration task definition."
  value       = aws_ecs_task_definition.migrate.arn
}

output "log_group_name" {
  description = "CloudWatch log group of the containers."
  value       = aws_cloudwatch_log_group.app.name
}

output "task_role_arn" {
  description = "IAM role assumed by the application."
  value       = aws_iam_role.task.arn
}
