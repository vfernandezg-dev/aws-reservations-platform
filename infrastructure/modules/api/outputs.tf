output "api_id" {
  description = "ID of the HTTP API (CloudWatch metric dimension)."
  value       = aws_apigatewayv2_api.this.id
}

output "api_endpoint" {
  description = "Default invoke URL of the HTTP API. Use the CloudFront URL instead: direct calls are rejected by the ALB."
  value       = aws_apigatewayv2_api.this.api_endpoint
}

output "stage_name" {
  description = "Name of the deployed stage."
  value       = aws_apigatewayv2_stage.default.name
}

output "access_log_group_name" {
  description = "CloudWatch log group with API access logs."
  value       = aws_cloudwatch_log_group.access.name
}
