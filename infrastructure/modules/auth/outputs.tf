output "user_pool_id" {
  description = "ID of the Cognito user pool."
  value       = aws_cognito_user_pool.this.id
}

output "user_pool_arn" {
  description = "ARN of the Cognito user pool."
  value       = aws_cognito_user_pool.this.arn
}

output "issuer_url" {
  description = "OIDC issuer URL used by the API Gateway JWT authorizer."
  value       = "https://${aws_cognito_user_pool.this.endpoint}"
}

output "client_id" {
  description = "ID of the SPA app client (JWT audience)."
  value       = aws_cognito_user_pool_client.spa.id
}

output "domain" {
  description = "Managed Login domain prefix."
  value       = aws_cognito_user_pool_domain.this.domain
}

output "hosted_ui_url" {
  description = "Base URL of the Cognito Managed Login pages."
  value       = "https://${aws_cognito_user_pool_domain.this.domain}.auth.${data.aws_region.current.region}.amazoncognito.com"
}
