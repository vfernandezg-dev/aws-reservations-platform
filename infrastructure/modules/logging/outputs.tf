output "bucket_id" {
  description = "Name of the log bucket. Depends on the bucket policy so log producers (ALB) are created only after they are allowed to write."
  value       = aws_s3_bucket.this.id

  depends_on = [aws_s3_bucket_policy.this]
}

output "bucket_arn" {
  description = "ARN of the log bucket."
  value       = aws_s3_bucket.this.arn

  depends_on = [aws_s3_bucket_policy.this]
}

output "alb_prefix" {
  description = "Key prefix for ALB access logs."
  value       = var.alb_prefix
}
