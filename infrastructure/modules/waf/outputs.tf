output "web_acl_arn" {
  description = "ARN of the Web ACL (attach to CloudFront via web_acl_id)."
  value       = aws_wafv2_web_acl.this.arn
}

output "web_acl_name" {
  description = "Name of the Web ACL (CloudWatch metric dimension)."
  value       = aws_wafv2_web_acl.this.name
}
