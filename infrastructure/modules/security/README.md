# Security groups

All security groups of the platform, chained tier by tier with security-group references (no CIDR-based ingress).

## Design

```text
VPC Link --80--> internal ALB --8080--> ECS tasks --5432--> Aurora
```

- Keeping every group in one module avoids cross-module dependency cycles between the ALB, API and ECS modules.
- Uses the current `aws_vpc_security_group_ingress_rule` / `egress_rule` resources (one rule per resource, each with a description).
- The only `0.0.0.0/0` rule is HTTPS egress from the tasks to AWS APIs (ECR, Logs, Secrets Manager) through NAT or interface endpoints.

## Usage

```hcl
module "security" {
  source = "./modules/security"

  name     = "reservations-dev"
  vpc_id   = module.network.vpc_id
  app_port = 8080
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
| [aws_security_group.alb](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_security_group.app](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_security_group.db](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_security_group.vpc_link](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_vpc_security_group_egress_rule.alb_to_app](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_egress_rule) | resource |
| [aws_vpc_security_group_egress_rule.app_https](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_egress_rule) | resource |
| [aws_vpc_security_group_egress_rule.app_to_db](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_egress_rule) | resource |
| [aws_vpc_security_group_egress_rule.vpc_link_to_alb](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_egress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.alb_from_vpc_link](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.app_from_alb](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.db_from_app](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |

### Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_name"></a> [name](#input\_name) | Name prefix for all resources (<project>-<environment>). | `string` | n/a | yes |
| <a name="input_vpc_id"></a> [vpc\_id](#input\_vpc\_id) | ID of the VPC the security groups belong to. | `string` | n/a | yes |
| <a name="input_app_port"></a> [app\_port](#input\_app\_port) | Port the application container listens on. | `number` | `8080` | no |
| <a name="input_db_port"></a> [db\_port](#input\_db\_port) | Port of the database engine. | `number` | `5432` | no |

### Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_alb_security_group_id"></a> [alb\_security\_group\_id](#output\_alb\_security\_group\_id) | Security group for the internal ALB. |
| <a name="output_app_security_group_id"></a> [app\_security\_group\_id](#output\_app\_security\_group\_id) | Security group for ECS tasks. |
| <a name="output_db_security_group_id"></a> [db\_security\_group\_id](#output\_db\_security\_group\_id) | Security group for the Aurora cluster. |
| <a name="output_vpc_link_security_group_id"></a> [vpc\_link\_security\_group\_id](#output\_vpc\_link\_security\_group\_id) | Security group for the API Gateway VPC Link. |
<!-- END_TF_DOCS -->
