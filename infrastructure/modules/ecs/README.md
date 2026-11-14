# ECS Fargate service

Container runtime for the API on AWS Fargate (Graviton/ARM64).

## Design

- Cluster with Container Insights (enhanced observability) and FARGATE / FARGATE_SPOT capacity providers (`use_fargate_spot` for non-production).
- Hardened task: ARM64, non-root distroless image, read-only root filesystem (plus a writable `/tmp` volume), `initProcessEnabled` and a container health check.
- ECS injects the database credentials from the Aurora-managed secret (`DB_USER` / `DB_PASSWORD`); they are never stored in the task definition or the state.
- Least-privilege roles: the execution role can only read that secret (and decrypt it with the KMS key); the task role has no permissions.
- Rolling deployments with a circuit breaker and automatic rollback, AZ rebalancing, and target-tracking auto scaling on CPU and ALB requests per target.
- A second task definition runs database migrations as a one-off task (`scripts/db-migrate.sh`).

## Usage

```hcl
module "ecs" {
  source = "./modules/ecs"

  name                    = "reservations-dev"
  image                   = "123456789012.dkr.ecr.us-east-1.amazonaws.com/reservations-app:3f2c1a9b8d7e"
  image_tag               = "3f2c1a9b8d7e"
  subnet_ids              = module.network.app_subnet_ids
  security_group_id       = module.security.app_security_group_id
  target_group_arn        = module.alb.target_group_arn
  alb_arn_suffix          = module.alb.arn_suffix
  target_group_arn_suffix = module.alb.target_group_arn_suffix
  db_host                 = module.aurora.endpoint
  db_name                 = module.aurora.database_name
  db_secret_arn           = module.aurora.master_user_secret_arn
  use_fargate_spot        = true
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
| [aws_appautoscaling_policy.cpu](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/appautoscaling_policy) | resource |
| [aws_appautoscaling_policy.requests](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/appautoscaling_policy) | resource |
| [aws_appautoscaling_target.app](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/appautoscaling_target) | resource |
| [aws_cloudwatch_log_group.app](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_ecs_cluster.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_cluster) | resource |
| [aws_ecs_cluster_capacity_providers.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_cluster_capacity_providers) | resource |
| [aws_ecs_service.app](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_service) | resource |
| [aws_ecs_task_definition.app](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_task_definition) | resource |
| [aws_ecs_task_definition.migrate](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_task_definition) | resource |
| [aws_iam_role.execution](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.task](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy.execution_secrets](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy_attachment.execution](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_policy_document.ecs_tasks_assume](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.execution_secrets](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |

### Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_alb_arn_suffix"></a> [alb\_arn\_suffix](#input\_alb\_arn\_suffix) | ALB ARN suffix (for the request-count scaling metric). | `string` | n/a | yes |
| <a name="input_db_host"></a> [db\_host](#input\_db\_host) | Aurora writer endpoint. | `string` | n/a | yes |
| <a name="input_db_name"></a> [db\_name](#input\_db\_name) | Database (schema) name. | `string` | n/a | yes |
| <a name="input_db_secret_arn"></a> [db\_secret\_arn](#input\_db\_secret\_arn) | ARN of the Secrets Manager secret holding the database credentials (Aurora-managed). | `string` | n/a | yes |
| <a name="input_image"></a> [image](#input\_image) | Full container image URI including tag, e.g. <account>.dkr.ecr.<region>.amazonaws.com/reservations-app:<git-sha>. | `string` | n/a | yes |
| <a name="input_image_tag"></a> [image\_tag](#input\_image\_tag) | Image tag, exposed to the app as APP\_VERSION. | `string` | n/a | yes |
| <a name="input_name"></a> [name](#input\_name) | Name prefix for all resources (<project>-<environment>). | `string` | n/a | yes |
| <a name="input_security_group_id"></a> [security\_group\_id](#input\_security\_group\_id) | Security group attached to the tasks. | `string` | n/a | yes |
| <a name="input_subnet_ids"></a> [subnet\_ids](#input\_subnet\_ids) | Private application subnets for the tasks. | `list(string)` | n/a | yes |
| <a name="input_target_group_arn"></a> [target\_group\_arn](#input\_target\_group\_arn) | ALB target group the service registers into. | `string` | n/a | yes |
| <a name="input_target_group_arn_suffix"></a> [target\_group\_arn\_suffix](#input\_target\_group\_arn\_suffix) | Target group ARN suffix (for the request-count scaling metric). | `string` | n/a | yes |
| <a name="input_container_port"></a> [container\_port](#input\_container\_port) | Port the container listens on. | `number` | `8080` | no |
| <a name="input_cpu"></a> [cpu](#input\_cpu) | Task CPU units (256 = 0.25 vCPU). | `number` | `256` | no |
| <a name="input_cpu_target_percent"></a> [cpu\_target\_percent](#input\_cpu\_target\_percent) | Target average CPU utilization for scaling. | `number` | `60` | no |
| <a name="input_db_port"></a> [db\_port](#input\_db\_port) | Aurora port. | `number` | `5432` | no |
| <a name="input_environment"></a> [environment](#input\_environment) | Extra non-secret environment variables for the container. | `map(string)` | `{}` | no |
| <a name="input_kms_key_arn"></a> [kms\_key\_arn](#input\_kms\_key\_arn) | Customer managed KMS key encrypting the log group and the database secret. Null uses AWS managed keys. | `string` | `null` | no |
| <a name="input_log_retention_days"></a> [log\_retention\_days](#input\_log\_retention\_days) | Retention of the container log group in days. | `number` | `30` | no |
| <a name="input_max_capacity"></a> [max\_capacity](#input\_max\_capacity) | Maximum number of running tasks. | `number` | `2` | no |
| <a name="input_memory"></a> [memory](#input\_memory) | Task memory in MiB (must be a valid Fargate combination with cpu). | `number` | `512` | no |
| <a name="input_min_capacity"></a> [min\_capacity](#input\_min\_capacity) | Minimum number of running tasks (also the initial desired count). | `number` | `1` | no |
| <a name="input_requests_per_target"></a> [requests\_per\_target](#input\_requests\_per\_target) | Target ALB requests per task per minute for scaling. | `number` | `500` | no |
| <a name="input_use_fargate_spot"></a> [use\_fargate\_spot](#input\_use\_fargate\_spot) | Run tasks on Fargate Spot (up to ~70% cheaper, can be interrupted). Recommended for non-production. | `bool` | `false` | no |
| <a name="input_wait_for_steady_state"></a> [wait\_for\_steady\_state](#input\_wait\_for\_steady\_state) | Make terraform apply wait until the service is stable (healthy tasks behind the ALB). | `bool` | `true` | no |

### Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_cluster_arn"></a> [cluster\_arn](#output\_cluster\_arn) | ARN of the ECS cluster. |
| <a name="output_cluster_name"></a> [cluster\_name](#output\_cluster\_name) | Name of the ECS cluster. |
| <a name="output_log_group_name"></a> [log\_group\_name](#output\_log\_group\_name) | CloudWatch log group of the containers. |
| <a name="output_migration_task_definition_arn"></a> [migration\_task\_definition\_arn](#output\_migration\_task\_definition\_arn) | ARN of the one-off database migration task definition. |
| <a name="output_service_name"></a> [service\_name](#output\_service\_name) | Name of the ECS service. |
| <a name="output_task_definition_arn"></a> [task\_definition\_arn](#output\_task\_definition\_arn) | ARN of the application task definition revision. |
| <a name="output_task_role_arn"></a> [task\_role\_arn](#output\_task\_role\_arn) | IAM role assumed by the application. |
<!-- END_TF_DOCS -->
