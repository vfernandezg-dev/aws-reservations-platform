# Internal Application Load Balancer

Private ALB in the application subnets, reachable only from the API Gateway VPC Link.

## Design

- The default action returns **403**; a listener rule forwards to the tasks only when the `X-Origin-Verify` header matches the secret injected by CloudFront.
- IP target group (Fargate `awsvpc`), health check on `/health` (which never depends on the database), `drop_invalid_header_fields`, strictest desync mitigation, and access logs to the central bucket.
- The listener is HTTP: traffic never leaves the private subnets and TLS terminates at CloudFront and API Gateway (see ADR 0003).

## Usage

```hcl
module "alb" {
  source = "./modules/alb"

  name                 = "reservations-dev"
  vpc_id               = module.network.vpc_id
  subnet_ids           = module.network.app_subnet_ids
  security_group_id    = module.security.alb_security_group_id
  origin_verify_secret = random_password.origin_verify.result
  access_logs_bucket   = module.logging.bucket_id
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
| [aws_lb.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb) | resource |
| [aws_lb_listener.http](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_listener) | resource |
| [aws_lb_listener_rule.origin_verified](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_listener_rule) | resource |
| [aws_lb_target_group.app](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_target_group) | resource |

### Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_name"></a> [name](#input\_name) | Name prefix for all resources (<project>-<environment>). Max 28 characters (ALB/TG name limits). | `string` | n/a | yes |
| <a name="input_origin_verify_secret"></a> [origin\_verify\_secret](#input\_origin\_verify\_secret) | Expected value of the secret header (alphanumeric, max 128 characters: ALB treats * and ? as wildcards). | `string` | n/a | yes |
| <a name="input_security_group_id"></a> [security\_group\_id](#input\_security\_group\_id) | Security group attached to the ALB. | `string` | n/a | yes |
| <a name="input_subnet_ids"></a> [subnet\_ids](#input\_subnet\_ids) | Private application subnets for the internal ALB (at least two AZs). | `list(string)` | n/a | yes |
| <a name="input_vpc_id"></a> [vpc\_id](#input\_vpc\_id) | ID of the VPC. | `string` | n/a | yes |
| <a name="input_access_logs_bucket"></a> [access\_logs\_bucket](#input\_access\_logs\_bucket) | S3 bucket for ALB access logs. Null disables access logs. | `string` | `null` | no |
| <a name="input_access_logs_prefix"></a> [access\_logs\_prefix](#input\_access\_logs\_prefix) | Key prefix for ALB access logs. | `string` | `"alb"` | no |
| <a name="input_deletion_protection"></a> [deletion\_protection](#input\_deletion\_protection) | Enable ALB deletion protection. | `bool` | `false` | no |
| <a name="input_health_check_path"></a> [health\_check\_path](#input\_health\_check\_path) | HTTP path used by target group health checks (must not depend on the database). | `string` | `"/health"` | no |
| <a name="input_origin_verify_header_name"></a> [origin\_verify\_header\_name](#input\_origin\_verify\_header\_name) | Name of the secret header that must be present for requests to be forwarded. | `string` | `"X-Origin-Verify"` | no |
| <a name="input_target_port"></a> [target\_port](#input\_target\_port) | Port the ECS tasks listen on. | `number` | `8080` | no |

### Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_arn"></a> [arn](#output\_arn) | ARN of the internal ALB. |
| <a name="output_arn_suffix"></a> [arn\_suffix](#output\_arn\_suffix) | ARN suffix of the ALB (CloudWatch metric dimension). |
| <a name="output_dns_name"></a> [dns\_name](#output\_dns\_name) | Internal DNS name of the ALB. |
| <a name="output_listener_arn"></a> [listener\_arn](#output\_listener\_arn) | ARN of the HTTP listener (API Gateway private integration target). |
| <a name="output_target_group_arn"></a> [target\_group\_arn](#output\_target\_group\_arn) | ARN of the application target group. Depends on the listener rule because ECS refuses target groups not yet attached to a load balancer. |
| <a name="output_target_group_arn_suffix"></a> [target\_group\_arn\_suffix](#output\_target\_group\_arn\_suffix) | ARN suffix of the target group (CloudWatch metric dimension). |
<!-- END_TF_DOCS -->
