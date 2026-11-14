# Logging

Central, private S3 bucket receiving ALB access logs, CloudFront standard logs (v2) and VPC Flow Logs.

## Design

- SSE-S3 encryption (a requirement of ALB access logs), versioning, Block Public Access and `BucketOwnerEnforced` (no ACLs).
- The bucket policy grants write access only to the ELB log-delivery principals and to `delivery.logs.amazonaws.com` for this account, and denies non-TLS requests.
- A lifecycle rule expires logs after `retention_days`.
- Outputs depend on the bucket policy, so producers (the ALB validates the bucket at creation) are created only after they are allowed to write.

## Usage

```hcl
module "logging" {
  source = "./modules/logging"

  name           = "reservations-dev"
  retention_days = 30
}
```

<!-- BEGIN_TF_DOCS -->
### Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.10 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 6.70 |

### Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_aws"></a> [aws](#provider\_aws) | >= 6.70 |

### Resources

| Name | Type |
| ---- | ---- |
| [aws_s3_bucket.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket) | resource |
| [aws_s3_bucket_lifecycle_configuration.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_lifecycle_configuration) | resource |
| [aws_s3_bucket_ownership_controls.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_ownership_controls) | resource |
| [aws_s3_bucket_policy.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_policy) | resource |
| [aws_s3_bucket_public_access_block.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_public_access_block) | resource |
| [aws_s3_bucket_server_side_encryption_configuration.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_server_side_encryption_configuration) | resource |
| [aws_s3_bucket_versioning.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_versioning) | resource |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_elb_service_account.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/elb_service_account) | data source |
| [aws_iam_policy_document.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |

### Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_name"></a> [name](#input\_name) | Name prefix for all resources (<project>-<environment>). | `string` | n/a | yes |
| <a name="input_alb_prefix"></a> [alb\_prefix](#input\_alb\_prefix) | Key prefix used for Application Load Balancer access logs. | `string` | `"alb"` | no |
| <a name="input_force_destroy"></a> [force\_destroy](#input\_force\_destroy) | Allow Terraform to delete the bucket even if it still contains logs (use only in ephemeral environments). | `bool` | `false` | no |
| <a name="input_retention_days"></a> [retention\_days](#input\_retention\_days) | Days to keep log objects before they expire. | `number` | `90` | no |

### Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_alb_prefix"></a> [alb\_prefix](#output\_alb\_prefix) | Key prefix for ALB access logs. |
| <a name="output_bucket_arn"></a> [bucket\_arn](#output\_bucket\_arn) | ARN of the log bucket. |
| <a name="output_bucket_id"></a> [bucket\_id](#output\_bucket\_id) | Name of the log bucket. Depends on the bucket policy so log producers (ALB) are created only after they are allowed to write. |
<!-- END_TF_DOCS -->
