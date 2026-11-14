# KMS

Customer managed KMS key (yearly rotation) with a key policy for CloudWatch Logs and for CloudWatch alarms publishing to SNS.

## Design

- The root module instantiates it twice: one key in the primary region (the database, its secret, log groups, SNS) and one in us-east-1 for edge resources (WAF logs, the global alarm topic).
- The key policy delegates to IAM (account root) and adds only the services that cannot use IAM: CloudWatch Logs for this account and region (encryption-context condition) and CloudWatch alarms publishing to encrypted SNS topics.

## Usage

```hcl
module "kms" {
  source = "./modules/kms"

  name = "reservations-prod"
}

module "kms_global" {
  source = "./modules/kms"

  name   = "reservations-prod-global"
  region = "us-east-1"
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
| [aws_kms_alias.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/kms_alias) | resource |
| [aws_kms_key.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/kms_key) | resource |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_iam_policy_document.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |

### Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_name"></a> [name](#input\_name) | Name of the key alias (alias/<name>). | `string` | n/a | yes |
| <a name="input_deletion_window_in_days"></a> [deletion\_window\_in\_days](#input\_deletion\_window\_in\_days) | Waiting period before a scheduled key deletion completes. | `number` | `30` | no |
| <a name="input_region"></a> [region](#input\_region) | Region for the key. Null uses the provider region; edge resources need a key in us-east-1. | `string` | `null` | no |

### Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_alias_name"></a> [alias\_name](#output\_alias\_name) | Alias of the key. |
| <a name="output_key_arn"></a> [key\_arn](#output\_key\_arn) | ARN of the customer managed key. |
| <a name="output_key_id"></a> [key\_id](#output\_key\_id) | ID of the customer managed key. |
<!-- END_TF_DOCS -->
