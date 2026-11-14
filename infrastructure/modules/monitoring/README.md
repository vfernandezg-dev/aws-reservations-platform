# Monitoring

CloudWatch alarms, SNS notifications and a dashboard covering every tier.

## Design

- Alarms: ALB 5xx (load balancer and targets), unhealthy targets, ECS CPU and memory, API Gateway 5xx, database CPU, free storage and freeable memory, CloudFront 5xx rate and WAF blocked-request spikes.
- CloudFront and WAF metrics only exist in us-east-1, and alarms can only notify a topic in their own region, hence a second (global) SNS topic.
- KMS-encrypted SNS topics with an optional email subscription.
- One dashboard: edge (CloudFront, WAF), API, ALB, ECS and the database.

## Usage

```hcl
module "monitoring" {
  source = "./modules/monitoring"

  name                       = "reservations-prod"
  alarm_email                = "oncall@example.com"
  alb_arn_suffix             = module.alb.arn_suffix
  target_group_arn_suffix    = module.alb.target_group_arn_suffix
  ecs_cluster_name           = module.ecs.cluster_name
  ecs_service_name           = module.ecs.service_name
  api_id                     = module.api.api_id
  db_instance_identifier     = module.database.identifier
  cloudfront_distribution_id = module.cdn.distribution_id
  waf_web_acl_name           = module.waf.web_acl_name
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
| [aws_cloudwatch_dashboard.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_dashboard) | resource |
| [aws_cloudwatch_metric_alarm.cloudfront_5xx_rate](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_metric_alarm) | resource |
| [aws_cloudwatch_metric_alarm.regional](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_metric_alarm) | resource |
| [aws_cloudwatch_metric_alarm.waf_blocked_spike](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_metric_alarm) | resource |
| [aws_sns_topic.alarms](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sns_topic) | resource |
| [aws_sns_topic.alarms_global](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sns_topic) | resource |
| [aws_sns_topic_subscription.email](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sns_topic_subscription) | resource |
| [aws_sns_topic_subscription.email_global](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sns_topic_subscription) | resource |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |

### Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_alb_arn_suffix"></a> [alb\_arn\_suffix](#input\_alb\_arn\_suffix) | ARN suffix of the internal ALB. | `string` | n/a | yes |
| <a name="input_api_id"></a> [api\_id](#input\_api\_id) | ID of the HTTP API. | `string` | n/a | yes |
| <a name="input_cloudfront_distribution_id"></a> [cloudfront\_distribution\_id](#input\_cloudfront\_distribution\_id) | ID of the CloudFront distribution. | `string` | n/a | yes |
| <a name="input_db_instance_identifier"></a> [db\_instance\_identifier](#input\_db\_instance\_identifier) | Identifier of the RDS DB instance. | `string` | n/a | yes |
| <a name="input_ecs_cluster_name"></a> [ecs\_cluster\_name](#input\_ecs\_cluster\_name) | Name of the ECS cluster. | `string` | n/a | yes |
| <a name="input_ecs_service_name"></a> [ecs\_service\_name](#input\_ecs\_service\_name) | Name of the ECS service. | `string` | n/a | yes |
| <a name="input_name"></a> [name](#input\_name) | Name prefix for all resources (<project>-<environment>). | `string` | n/a | yes |
| <a name="input_target_group_arn_suffix"></a> [target\_group\_arn\_suffix](#input\_target\_group\_arn\_suffix) | ARN suffix of the application target group. | `string` | n/a | yes |
| <a name="input_waf_web_acl_name"></a> [waf\_web\_acl\_name](#input\_waf\_web\_acl\_name) | Name of the WAF Web ACL. | `string` | n/a | yes |
| <a name="input_alarm_email"></a> [alarm\_email](#input\_alarm\_email) | Email address subscribed to alarm notifications (confirmation required). Null disables the subscription. | `string` | `null` | no |
| <a name="input_global_kms_key_arn"></a> [global\_kms\_key\_arn](#input\_global\_kms\_key\_arn) | Customer managed KMS key in us-east-1 for the global SNS topic. Null leaves the topic unencrypted. | `string` | `null` | no |
| <a name="input_kms_key_arn"></a> [kms\_key\_arn](#input\_kms\_key\_arn) | Customer managed KMS key for the regional SNS topic (its policy must allow cloudwatch.amazonaws.com). Null leaves the topic unencrypted. | `string` | `null` | no |
| <a name="input_waf_blocked_requests_threshold"></a> [waf\_blocked\_requests\_threshold](#input\_waf\_blocked\_requests\_threshold) | Blocked requests per 5 minutes that trigger the WAF spike alarm. | `number` | `500` | no |

### Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_alarm_topic_arn"></a> [alarm\_topic\_arn](#output\_alarm\_topic\_arn) | SNS topic receiving regional alarms. |
| <a name="output_dashboard_name"></a> [dashboard\_name](#output\_dashboard\_name) | Name of the CloudWatch dashboard. |
| <a name="output_global_alarm_topic_arn"></a> [global\_alarm\_topic\_arn](#output\_global\_alarm\_topic\_arn) | SNS topic (us-east-1) receiving CloudFront and WAF alarms. |
<!-- END_TF_DOCS -->
