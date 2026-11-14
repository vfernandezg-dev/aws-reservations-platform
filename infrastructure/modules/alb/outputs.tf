output "arn" {
  description = "ARN of the internal ALB."
  value       = aws_lb.this.arn
}

output "arn_suffix" {
  description = "ARN suffix of the ALB (CloudWatch metric dimension)."
  value       = aws_lb.this.arn_suffix
}

output "dns_name" {
  description = "Internal DNS name of the ALB."
  value       = aws_lb.this.dns_name
}

output "listener_arn" {
  description = "ARN of the HTTP listener (API Gateway private integration target)."
  value       = aws_lb_listener.http.arn
}

output "target_group_arn" {
  description = "ARN of the application target group. Depends on the listener rule because ECS refuses target groups not yet attached to a load balancer."
  value       = aws_lb_target_group.app.arn

  depends_on = [aws_lb_listener_rule.origin_verified]
}

output "target_group_arn_suffix" {
  description = "ARN suffix of the target group (CloudWatch metric dimension)."
  value       = aws_lb_target_group.app.arn_suffix
}
