output "vpc_link_security_group_id" {
  description = "Security group for the API Gateway VPC Link."
  value       = aws_security_group.vpc_link.id
}

output "alb_security_group_id" {
  description = "Security group for the internal ALB."
  value       = aws_security_group.alb.id
}

output "app_security_group_id" {
  description = "Security group for ECS tasks."
  value       = aws_security_group.app.id
}

output "db_security_group_id" {
  description = "Security group for the Aurora cluster."
  value       = aws_security_group.db.id
}
