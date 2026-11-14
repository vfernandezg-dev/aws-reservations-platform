# Database (RDS for PostgreSQL 18)

Private, encrypted RDS for PostgreSQL 18 instance in the isolated data subnets.

## Design

- **Graviton** instance classes (`db.t4g.*`), gp3 storage with **storage autoscaling** up to `max_allocated_storage`.
- **High availability**: `multi_az = true` adds a synchronous standby in another AZ with automatic failover (production).
- **No password in Terraform**: `manage_master_user_password = true` lets RDS generate and rotate the master password in Secrets Manager.
- Encrypted with a customer managed KMS key (storage, Performance Insights, the secret and the log groups), TLS enforced (`rds.force_ssl = 1`), IAM database authentication enabled, never publicly accessible.
- Audit trail in the parameter group: every connection stage (`log_connections = all`, PostgreSQL 18 syntax), disconnections, every DDL statement and statements slower than 2 s, exported (with IAM authentication errors) to pre-created log groups with managed retention.
- Backups with point-in-time recovery, deletion protection and a uniquely named final snapshot in protected environments.

> Why not Aurora? AWS Free-plan accounts can only create Aurora clusters through *express configuration*
> (outside the VPC, reachable over the internet), which contradicts the private data tier. See
> [ADR 0005](../../../docs/adr/0005-rds-postgresql.md). Aurora Serverless v2 remains the natural upgrade
> path on paid accounts.

## Usage

```hcl
module "database" {
  source = "./modules/database"

  name              = "reservations-prod"
  subnet_ids        = module.network.data_subnet_ids
  security_group_id = module.security.db_security_group_id
  instance_class    = "db.t4g.small"
  multi_az          = true
  kms_key_arn       = module.kms.key_arn
}
```

<!-- BEGIN_TF_DOCS -->
### Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.10 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 6.70 |
| <a name="requirement_random"></a> [random](#requirement\_random) | >= 3.7 |

### Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_aws"></a> [aws](#provider\_aws) | >= 6.70 |
| <a name="provider_random"></a> [random](#provider\_random) | >= 3.7 |

### Resources

| Name | Type |
| ---- | ---- |
| [aws_cloudwatch_log_group.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_db_instance.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/db_instance) | resource |
| [aws_db_parameter_group.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/db_parameter_group) | resource |
| [aws_db_subnet_group.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/db_subnet_group) | resource |
| [aws_iam_role.monitoring](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy_attachment.monitoring](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [random_id.final_snapshot](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/id) | resource |
| [aws_iam_policy_document.monitoring_assume](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |

### Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_name"></a> [name](#input\_name) | Name prefix for all resources (<project>-<environment>). | `string` | n/a | yes |
| <a name="input_security_group_id"></a> [security\_group\_id](#input\_security\_group\_id) | Security group attached to the instance. | `string` | n/a | yes |
| <a name="input_subnet_ids"></a> [subnet\_ids](#input\_subnet\_ids) | Isolated data subnets (at least two AZs). | `list(string)` | n/a | yes |
| <a name="input_allocated_storage"></a> [allocated\_storage](#input\_allocated\_storage) | Initial gp3 storage in GiB. | `number` | `20` | no |
| <a name="input_backup_retention_days"></a> [backup\_retention\_days](#input\_backup\_retention\_days) | Days to keep automated backups (point-in-time recovery window). | `number` | `7` | no |
| <a name="input_database_name"></a> [database\_name](#input\_database\_name) | Name of the initial database. | `string` | `"reservations"` | no |
| <a name="input_deletion_protection"></a> [deletion\_protection](#input\_deletion\_protection) | Prevent the instance from being deleted (also keeps automated backups on deletion). | `bool` | `true` | no |
| <a name="input_engine_version"></a> [engine\_version](#input\_engine\_version) | RDS for PostgreSQL engine version. | `string` | `"18.6"` | no |
| <a name="input_enhanced_monitoring_interval"></a> [enhanced\_monitoring\_interval](#input\_enhanced\_monitoring\_interval) | Enhanced Monitoring granularity in seconds (0 disables it). | `number` | `0` | no |
| <a name="input_instance_class"></a> [instance\_class](#input\_instance\_class) | Instance class. Graviton (db.t4g/db.m7g/db.r7g) is cheaper than x86 for the same size. | `string` | `"db.t4g.micro"` | no |
| <a name="input_kms_key_arn"></a> [kms\_key\_arn](#input\_kms\_key\_arn) | Customer managed KMS key for storage, Performance Insights, the master secret and log groups. Null uses AWS managed keys. | `string` | `null` | no |
| <a name="input_log_retention_days"></a> [log\_retention\_days](#input\_log\_retention\_days) | Retention of the exported database log groups in days. | `number` | `30` | no |
| <a name="input_master_username"></a> [master\_username](#input\_master\_username) | Master user name. The password is managed by RDS in Secrets Manager. | `string` | `"app_admin"` | no |
| <a name="input_max_allocated_storage"></a> [max\_allocated\_storage](#input\_max\_allocated\_storage) | Upper limit for storage autoscaling in GiB (0 disables autoscaling). | `number` | `100` | no |
| <a name="input_multi_az"></a> [multi\_az](#input\_multi\_az) | Run a synchronous standby in another AZ with automatic failover. | `bool` | `false` | no |
| <a name="input_parameter_group_family"></a> [parameter\_group\_family](#input\_parameter\_group\_family) | Parameter group family matching engine\_version. | `string` | `"postgres18"` | no |
| <a name="input_performance_insights_enabled"></a> [performance\_insights\_enabled](#input\_performance\_insights\_enabled) | Enable Performance Insights (7 days of retention, KMS-encrypted). | `bool` | `false` | no |
| <a name="input_port"></a> [port](#input\_port) | Database port. | `number` | `5432` | no |
| <a name="input_skip_final_snapshot"></a> [skip\_final\_snapshot](#input\_skip\_final\_snapshot) | Skip the final snapshot on deletion (only for disposable environments). | `bool` | `false` | no |

### Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_address"></a> [address](#output\_address) | Hostname of the DB instance (private DNS, follows Multi-AZ failover). |
| <a name="output_arn"></a> [arn](#output\_arn) | ARN of the DB instance. |
| <a name="output_database_name"></a> [database\_name](#output\_database\_name) | Name of the initial database. |
| <a name="output_identifier"></a> [identifier](#output\_identifier) | Identifier of the DB instance (CloudWatch metric dimension). |
| <a name="output_master_user_secret_arn"></a> [master\_user\_secret\_arn](#output\_master\_user\_secret\_arn) | ARN of the RDS-managed Secrets Manager secret with the master credentials. |
| <a name="output_port"></a> [port](#output\_port) | Database port. |
<!-- END_TF_DOCS -->
