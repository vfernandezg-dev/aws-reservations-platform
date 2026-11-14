# WAF

AWS WAFv2 Web ACL (CLOUDFRONT scope) protecting the distribution.

## Design

- Created in us-east-1 through the AWS provider v6 per-resource `region` argument, so callers need no provider alias.
- AWS managed rule groups: Amazon IP reputation, core rule set (`SizeRestrictions_BODY` set to count), known bad inputs (including Log4Shell) and SQL injection, plus a per-IP rate limit and optional geo blocking.
- Logs to a KMS-encrypted CloudWatch log group named `aws-waf-logs-*` (mandatory prefix) with the `Authorization` and `Cookie` headers redacted.

## Usage

```hcl
module "waf" {
  source = "./modules/waf"

  name                     = "reservations-dev"
  rate_limit_per_5_minutes = 1000
  kms_key_arn              = module.kms_global.key_arn
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
| [aws_cloudwatch_log_group.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_cloudwatch_log_resource_policy.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_resource_policy) | resource |
| [aws_wafv2_web_acl.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/wafv2_web_acl) | resource |
| [aws_wafv2_web_acl_logging_configuration.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/wafv2_web_acl_logging_configuration) | resource |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_iam_policy_document.logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |

### Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_name"></a> [name](#input\_name) | Name prefix for all resources (<project>-<environment>). | `string` | n/a | yes |
| <a name="input_blocked_country_codes"></a> [blocked\_country\_codes](#input\_blocked\_country\_codes) | ISO 3166-1 alpha-2 country codes to block at the edge. Empty list disables geo blocking. | `list(string)` | `[]` | no |
| <a name="input_enable_logging"></a> [enable\_logging](#input\_enable\_logging) | Send WAF logs (with Authorization/Cookie headers redacted) to CloudWatch Logs. | `bool` | `true` | no |
| <a name="input_kms_key_arn"></a> [kms\_key\_arn](#input\_kms\_key\_arn) | Customer managed KMS key in us-east-1 for the WAF log group. Null uses CloudWatch default encryption. | `string` | `null` | no |
| <a name="input_log_retention_days"></a> [log\_retention\_days](#input\_log\_retention\_days) | Retention of the WAF log group in days. | `number` | `30` | no |
| <a name="input_rate_limit_per_5_minutes"></a> [rate\_limit\_per\_5\_minutes](#input\_rate\_limit\_per\_5\_minutes) | Maximum requests a single IP may send in a 5-minute window before it is blocked. | `number` | `2000` | no |

### Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_web_acl_arn"></a> [web\_acl\_arn](#output\_web\_acl\_arn) | ARN of the Web ACL (attach to CloudFront via web\_acl\_id). |
| <a name="output_web_acl_name"></a> [web\_acl\_name](#output\_web\_acl\_name) | Name of the Web ACL (CloudWatch metric dimension). |
<!-- END_TF_DOCS -->
