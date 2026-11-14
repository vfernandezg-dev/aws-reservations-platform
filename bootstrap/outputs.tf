output "state_bucket_name" {
  description = "S3 bucket holding the Terraform state of every environment."
  value       = aws_s3_bucket.state.id
}

output "ecr_repository_url" {
  description = "URL of the shared application image repository."
  value       = aws_ecr_repository.app.repository_url
}

output "plan_role_arn" {
  description = "Role assumed by GitHub Actions for terraform plan."
  value       = aws_iam_role.plan.arn
}

output "apply_role_arn" {
  description = "Role assumed by GitHub Actions for terraform apply/destroy."
  value       = aws_iam_role.apply.arn
}

output "ecr_push_role_arn" {
  description = "Role assumed by GitHub Actions to push images."
  value       = aws_iam_role.ecr_push.arn
}

output "github_actions_variables" {
  description = "Repository variables to configure in GitHub (Settings > Secrets and variables > Actions > Variables)."
  value = {
    AWS_REGION            = var.aws_region
    TF_STATE_BUCKET       = aws_s3_bucket.state.id
    AWS_PLAN_ROLE_ARN     = aws_iam_role.plan.arn
    AWS_APPLY_ROLE_ARN    = aws_iam_role.apply.arn
    AWS_ECR_PUSH_ROLE_ARN = aws_iam_role.ecr_push.arn
    ECR_REPOSITORY        = aws_ecr_repository.app.name
  }
}

output "state_kms_key_arn" {
  description = "KMS key encrypting the state bucket."
  value       = aws_kms_key.state.arn
}
