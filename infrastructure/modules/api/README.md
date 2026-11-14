# API (API Gateway HTTP API)

HTTP API with a Cognito JWT authorizer and a private integration (VPC Link) to the internal ALB.

## Design

| Route | Auth | Purpose |
|---|---|---|
| `GET /api/health` | none | liveness through the whole chain |
| `ANY /api/public/{proxy+}` | none | anonymous endpoints |
| `ANY /api/{proxy+}` | Cognito JWT (when `enable_auth`) | protected endpoints |

- Anonymous routes strip the `x-user-*` headers; the protected route overwrites them with the verified JWT claims (`sub`, `email`), so the application can trust them.
- `$default` stage with auto-deploy, throttling (rate and burst are always both set) and structured JSON access logs.

## Usage

```hcl
module "api" {
  source = "./modules/api"

  name                       = "reservations-dev"
  vpc_link_subnet_ids        = module.network.app_subnet_ids
  vpc_link_security_group_id = module.security.vpc_link_security_group_id
  alb_listener_arn           = module.alb.listener_arn
  enable_auth                = true
  jwt_issuer                 = module.auth.issuer_url
  jwt_audience               = [module.auth.client_id]
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
| [aws_apigatewayv2_api.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/apigatewayv2_api) | resource |
| [aws_apigatewayv2_authorizer.cognito](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/apigatewayv2_authorizer) | resource |
| [aws_apigatewayv2_integration.authenticated](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/apigatewayv2_integration) | resource |
| [aws_apigatewayv2_integration.public](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/apigatewayv2_integration) | resource |
| [aws_apigatewayv2_route.health](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/apigatewayv2_route) | resource |
| [aws_apigatewayv2_route.protected](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/apigatewayv2_route) | resource |
| [aws_apigatewayv2_route.public](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/apigatewayv2_route) | resource |
| [aws_apigatewayv2_stage.default](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/apigatewayv2_stage) | resource |
| [aws_apigatewayv2_vpc_link.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/apigatewayv2_vpc_link) | resource |
| [aws_cloudwatch_log_group.access](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |

### Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_alb_listener_arn"></a> [alb\_listener\_arn](#input\_alb\_listener\_arn) | ARN of the internal ALB listener used as private integration target. | `string` | n/a | yes |
| <a name="input_name"></a> [name](#input\_name) | Name prefix for all resources (<project>-<environment>). | `string` | n/a | yes |
| <a name="input_vpc_link_security_group_id"></a> [vpc\_link\_security\_group\_id](#input\_vpc\_link\_security\_group\_id) | Security group attached to the VPC Link. | `string` | n/a | yes |
| <a name="input_vpc_link_subnet_ids"></a> [vpc\_link\_subnet\_ids](#input\_vpc\_link\_subnet\_ids) | Private subnets where the VPC Link ENIs are placed. | `list(string)` | n/a | yes |
| <a name="input_enable_auth"></a> [enable\_auth](#input\_enable\_auth) | Protect /api/{proxy+} with the Cognito JWT authorizer. /api/health and /api/public/* stay anonymous. | `bool` | `true` | no |
| <a name="input_jwt_audience"></a> [jwt\_audience](#input\_jwt\_audience) | Accepted JWT audiences (Cognito app client IDs). | `list(string)` | `[]` | no |
| <a name="input_jwt_issuer"></a> [jwt\_issuer](#input\_jwt\_issuer) | JWT issuer URL (https://cognito-idp.<region>.amazonaws.com/<user-pool-id>). Required when enable\_auth is true. | `string` | `null` | no |
| <a name="input_kms_key_arn"></a> [kms\_key\_arn](#input\_kms\_key\_arn) | Customer managed KMS key for the access log group. Null uses CloudWatch default encryption. | `string` | `null` | no |
| <a name="input_log_retention_days"></a> [log\_retention\_days](#input\_log\_retention\_days) | Retention of the access log group in days. | `number` | `30` | no |
| <a name="input_throttling_burst_limit"></a> [throttling\_burst\_limit](#input\_throttling\_burst\_limit) | Burst capacity for the stage. | `number` | `200` | no |
| <a name="input_throttling_rate_limit"></a> [throttling\_rate\_limit](#input\_throttling\_rate\_limit) | Steady-state requests per second allowed for the stage. | `number` | `100` | no |

### Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_access_log_group_name"></a> [access\_log\_group\_name](#output\_access\_log\_group\_name) | CloudWatch log group with API access logs. |
| <a name="output_api_endpoint"></a> [api\_endpoint](#output\_api\_endpoint) | Default invoke URL of the HTTP API. Use the CloudFront URL instead: direct calls are rejected by the ALB. |
| <a name="output_api_id"></a> [api\_id](#output\_api\_id) | ID of the HTTP API (CloudWatch metric dimension). |
| <a name="output_stage_name"></a> [stage\_name](#output\_stage\_name) | Name of the deployed stage. |
<!-- END_TF_DOCS -->
