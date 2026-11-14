# Infrastructure (root module)

Composes the platform from the modules in [`modules/`](modules). One root
module serves every environment; differences live only in
[`environments/<env>.tfvars`](environments) and each environment has its own
state file (`environments/<env>.s3.tfbackend`).

```text
kms ─┬─ logging ── network ── security
     │                          │
     │        ┌─────────────────┼──────────────────┐
     │     database            alb ── ecs        api ── auth
     │                          │                  │
     └─ waf ──────────────── cdn ── storage ───────┘
                                │
                           monitoring
```

## Usage

```bash
# From the repository root (see the Makefile)
make plan  ENV=dev APP_IMAGE_TAG=<git-sha>
make apply ENV=dev

# Plain Terraform
terraform -chdir=infrastructure init -reconfigure \
  -backend-config=environments/dev.s3.tfbackend \
  -backend-config="bucket=<state-bucket>"
terraform -chdir=infrastructure plan \
  -var-file=environments/dev.tfvars -var="app_image_tag=<git-sha>" -out=dev.tfplan
```

## Tests

`terraform test` runs the suites in [`tests/`](tests) against the modules with
a mocked AWS provider: no credentials, no cost, a few seconds.

```bash
terraform -chdir=infrastructure init -backend=false
terraform -chdir=infrastructure test
```

<!-- BEGIN_TF_DOCS -->
### Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.10, < 2.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | ~> 6.70 |
| <a name="requirement_http"></a> [http](#requirement\_http) | ~> 3.5 |
| <a name="requirement_random"></a> [random](#requirement\_random) | ~> 3.7 |

### Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_aws"></a> [aws](#provider\_aws) | ~> 6.70 |
| <a name="provider_random"></a> [random](#provider\_random) | ~> 3.7 |

### Modules

| Name | Source | Version |
| ---- | ------ | ------- |
| <a name="module_alb"></a> [alb](#module\_alb) | ./modules/alb | n/a |
| <a name="module_api"></a> [api](#module\_api) | ./modules/api | n/a |
| <a name="module_auth"></a> [auth](#module\_auth) | ./modules/auth | n/a |
| <a name="module_cdn"></a> [cdn](#module\_cdn) | ./modules/cdn | n/a |
| <a name="module_database"></a> [database](#module\_database) | ./modules/database | n/a |
| <a name="module_ecs"></a> [ecs](#module\_ecs) | ./modules/ecs | n/a |
| <a name="module_kms"></a> [kms](#module\_kms) | ./modules/kms | n/a |
| <a name="module_kms_global"></a> [kms\_global](#module\_kms\_global) | ./modules/kms | n/a |
| <a name="module_logging"></a> [logging](#module\_logging) | ./modules/logging | n/a |
| <a name="module_monitoring"></a> [monitoring](#module\_monitoring) | ./modules/monitoring | n/a |
| <a name="module_network"></a> [network](#module\_network) | ./modules/network | n/a |
| <a name="module_security"></a> [security](#module\_security) | ./modules/security | n/a |
| <a name="module_storage"></a> [storage](#module\_storage) | ./modules/storage | n/a |
| <a name="module_waf"></a> [waf](#module\_waf) | ./modules/waf | n/a |

### Resources

| Name | Type |
| ---- | ---- |
| [random_password.origin_verify](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/password) | resource |
| [aws_availability_zones.available](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/availability_zones) | data source |
| [aws_ecr_repository.app](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ecr_repository) | data source |

### Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_app_image_tag"></a> [app\_image\_tag](#input\_app\_image\_tag) | Immutable image tag to deploy (git commit SHA produced by the app pipeline). | `string` | n/a | yes |
| <a name="input_environment"></a> [environment](#input\_environment) | Deployment environment. | `string` | n/a | yes |
| <a name="input_alarm_email"></a> [alarm\_email](#input\_alarm\_email) | Optional email address for CloudWatch alarm notifications. | `string` | `null` | no |
| <a name="input_api_throttling_burst_limit"></a> [api\_throttling\_burst\_limit](#input\_api\_throttling\_burst\_limit) | API Gateway burst capacity. | `number` | `200` | no |
| <a name="input_api_throttling_rate_limit"></a> [api\_throttling\_rate\_limit](#input\_api\_throttling\_rate\_limit) | API Gateway steady-state requests per second. | `number` | `100` | no |
| <a name="input_app_cpu"></a> [app\_cpu](#input\_app\_cpu) | Fargate task CPU units. | `number` | `256` | no |
| <a name="input_app_max_capacity"></a> [app\_max\_capacity](#input\_app\_max\_capacity) | Maximum number of tasks. | `number` | `2` | no |
| <a name="input_app_memory"></a> [app\_memory](#input\_app\_memory) | Fargate task memory (MiB). | `number` | `512` | no |
| <a name="input_app_min_capacity"></a> [app\_min\_capacity](#input\_app\_min\_capacity) | Minimum number of tasks. | `number` | `1` | no |
| <a name="input_aws_region"></a> [aws\_region](#input\_aws\_region) | Primary AWS region. Edge resources (CloudFront, WAF) are always in us-east-1. | `string` | `"us-east-1"` | no |
| <a name="input_az_count"></a> [az\_count](#input\_az\_count) | Number of Availability Zones to use (2 or 3). | `number` | `2` | no |
| <a name="input_cloudfront_price_class"></a> [cloudfront\_price\_class](#input\_cloudfront\_price\_class) | CloudFront price class. | `string` | `"PriceClass_100"` | no |
| <a name="input_cognito_mfa"></a> [cognito\_mfa](#input\_cognito\_mfa) | Cognito MFA mode: OFF, OPTIONAL or ON. | `string` | `"OPTIONAL"` | no |
| <a name="input_cost_center"></a> [cost\_center](#input\_cost\_center) | Cost allocation tag value (CostCenter tag). | `string` | `"portfolio"` | no |
| <a name="input_db_allocated_storage"></a> [db\_allocated\_storage](#input\_db\_allocated\_storage) | Initial gp3 storage in GiB. | `number` | `20` | no |
| <a name="input_db_backup_retention_days"></a> [db\_backup\_retention\_days](#input\_db\_backup\_retention\_days) | Automated backup retention in days. | `number` | `7` | no |
| <a name="input_db_enhanced_monitoring_interval"></a> [db\_enhanced\_monitoring\_interval](#input\_db\_enhanced\_monitoring\_interval) | Enhanced Monitoring interval in seconds (0 disables it). | `number` | `0` | no |
| <a name="input_db_instance_class"></a> [db\_instance\_class](#input\_db\_instance\_class) | RDS instance class (Graviton db.t4g.* recommended). | `string` | `"db.t4g.micro"` | no |
| <a name="input_db_max_allocated_storage"></a> [db\_max\_allocated\_storage](#input\_db\_max\_allocated\_storage) | Storage autoscaling limit in GiB (0 disables autoscaling). | `number` | `100` | no |
| <a name="input_db_multi_az"></a> [db\_multi\_az](#input\_db\_multi\_az) | Synchronous standby in a second AZ with automatic failover. | `bool` | `false` | no |
| <a name="input_db_performance_insights"></a> [db\_performance\_insights](#input\_db\_performance\_insights) | Enable Performance Insights. | `bool` | `false` | no |
| <a name="input_deletion_protection"></a> [deletion\_protection](#input\_deletion\_protection) | Enable deletion protection on stateful resources (RDS, Cognito, ALB) and keep data on destroy. | `bool` | `true` | no |
| <a name="input_ecr_repository_name"></a> [ecr\_repository\_name](#input\_ecr\_repository\_name) | Name of the ECR repository created by the bootstrap stack. | `string` | `"reservations-app"` | no |
| <a name="input_enable_auth"></a> [enable\_auth](#input\_enable\_auth) | Require a Cognito JWT on /api/{proxy+} (public and health routes stay open). | `bool` | `true` | no |
| <a name="input_enable_hosted_ui"></a> [enable\_hosted\_ui](#input\_enable\_hosted\_ui) | Enable Cognito Managed Login with the CloudFront URL as OAuth callback. | `bool` | `false` | no |
| <a name="input_interface_endpoint_services"></a> [interface\_endpoint\_services](#input\_interface\_endpoint\_services) | Interface VPC endpoints to create, e.g. ["ecr.api", "ecr.dkr", "logs", "secretsmanager"]. | `list(string)` | `[]` | no |
| <a name="input_log_retention_days"></a> [log\_retention\_days](#input\_log\_retention\_days) | Retention in days for CloudWatch log groups and S3 access logs. | `number` | `30` | no |
| <a name="input_owner"></a> [owner](#input\_owner) | Team or person accountable for the resources (Owner tag). | `string` | `"platform-team"` | no |
| <a name="input_project_name"></a> [project\_name](#input\_project\_name) | Short project identifier used as prefix for every resource name. | `string` | `"reservations"` | no |
| <a name="input_repository"></a> [repository](#input\_repository) | Source repository of this code (Repository tag). | `string` | `"aws-reservations-platform"` | no |
| <a name="input_single_nat_gateway"></a> [single\_nat\_gateway](#input\_single\_nat\_gateway) | Share one NAT gateway across AZs (cost saving for non-production). | `bool` | `false` | no |
| <a name="input_use_fargate_spot"></a> [use\_fargate\_spot](#input\_use\_fargate\_spot) | Run tasks on Fargate Spot. | `bool` | `false` | no |
| <a name="input_vpc_cidr"></a> [vpc\_cidr](#input\_vpc\_cidr) | IPv4 /16 CIDR block of the VPC. | `string` | `"10.20.0.0/16"` | no |
| <a name="input_waf_blocked_country_codes"></a> [waf\_blocked\_country\_codes](#input\_waf\_blocked\_country\_codes) | Countries (ISO alpha-2) blocked at the edge. | `list(string)` | `[]` | no |
| <a name="input_waf_rate_limit_per_5_minutes"></a> [waf\_rate\_limit\_per\_5\_minutes](#input\_waf\_rate\_limit\_per\_5\_minutes) | Requests allowed per client IP in 5 minutes before WAF blocks it. | `number` | `2000` | no |

### Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_api_endpoint"></a> [api\_endpoint](#output\_api\_endpoint) | Raw HTTP API endpoint. Direct calls are rejected by the ALB; use cloudfront\_url. |
| <a name="output_app_image_tag"></a> [app\_image\_tag](#output\_app\_image\_tag) | Image tag currently deployed (CI plans reuse it unless a new tag is given). |
| <a name="output_app_security_group_id"></a> [app\_security\_group\_id](#output\_app\_security\_group\_id) | Security group of the application tasks (used to run one-off tasks). |
| <a name="output_app_subnet_ids"></a> [app\_subnet\_ids](#output\_app\_subnet\_ids) | Private application subnets (used to run one-off tasks). |
| <a name="output_cloudfront_distribution_id"></a> [cloudfront\_distribution\_id](#output\_cloudfront\_distribution\_id) | CloudFront distribution ID (cache invalidations). |
| <a name="output_cloudfront_url"></a> [cloudfront\_url](#output\_cloudfront\_url) | Public entry point of the platform (static site + /api/*). |
| <a name="output_cognito_client_id"></a> [cognito\_client\_id](#output\_cognito\_client\_id) | Cognito SPA app client ID. |
| <a name="output_cognito_hosted_ui_url"></a> [cognito\_hosted\_ui\_url](#output\_cognito\_hosted\_ui\_url) | Base URL of the Cognito Managed Login pages. |
| <a name="output_cognito_user_pool_id"></a> [cognito\_user\_pool\_id](#output\_cognito\_user\_pool\_id) | Cognito user pool ID. |
| <a name="output_dashboard_url"></a> [dashboard\_url](#output\_dashboard\_url) | CloudWatch dashboard for the environment. |
| <a name="output_db_address"></a> [db\_address](#output\_db\_address) | PostgreSQL hostname (reachable only from the application subnets). |
| <a name="output_db_secret_arn"></a> [db\_secret\_arn](#output\_db\_secret\_arn) | Secrets Manager ARN of the RDS-managed database credentials. |
| <a name="output_ecs_cluster_name"></a> [ecs\_cluster\_name](#output\_ecs\_cluster\_name) | ECS cluster name. |
| <a name="output_ecs_log_group_name"></a> [ecs\_log\_group\_name](#output\_ecs\_log\_group\_name) | CloudWatch log group of the application containers. |
| <a name="output_ecs_service_name"></a> [ecs\_service\_name](#output\_ecs\_service\_name) | ECS service name. |
| <a name="output_environment"></a> [environment](#output\_environment) | Environment this state belongs to (used by scripts as a safety check). |
| <a name="output_migration_task_definition_arn"></a> [migration\_task\_definition\_arn](#output\_migration\_task\_definition\_arn) | Task definition used by scripts/db-migrate.sh. |
<!-- END_TF_DOCS -->
