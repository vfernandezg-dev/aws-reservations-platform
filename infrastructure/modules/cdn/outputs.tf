output "distribution_id" {
  description = "ID of the CloudFront distribution."
  value       = aws_cloudfront_distribution.this.id
}

output "distribution_arn" {
  description = "ARN of the CloudFront distribution."
  value       = aws_cloudfront_distribution.this.arn
}

output "domain_name" {
  description = "CloudFront domain name (dxxxx.cloudfront.net)."
  value       = aws_cloudfront_distribution.this.domain_name
}

output "url" {
  description = "Public HTTPS URL of the platform."
  value       = "https://${local.use_custom_domain ? var.aliases[0] : aws_cloudfront_distribution.this.domain_name}"
}
