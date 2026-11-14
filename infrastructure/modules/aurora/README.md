# Aurora Serverless v2 (PostgreSQL 18)

Aurora PostgreSQL 18 cluster with Serverless v2 instances in the isolated data subnets.

## Design

- **Scale to zero**: with `min_capacity = 0` the cluster pauses after `seconds_until_auto_pause` of inactivity, so an idle dev or staging database costs little more than its storage. Production keeps a warm minimum and a reader in another AZ for Multi-AZ failover (`instance_count = 2`).
- **No password in Terraform**: `manage_master_user_password = true` lets RDS generate and rotate the master password in Secrets Manager.
- Encrypted with a customer managed KMS key (storage, Performance Insights, the secret and the log groups), TLS enforced (`rds.force_ssl = 1`), IAM database authentication enabled.
- Audit trail through the cluster parameter group: connections, disconnections, every DDL statement and statements slower than 2 s, exported (with IAM authentication errors) to pre-created log groups with managed retention.
- Backups with point-in-time recovery, deletion protection and a uniquely named final snapshot in protected environments.

## Usage

```hcl
module "aurora" {
  source = "./modules/aurora"

  name              = "reservations-dev"
  subnet_ids        = module.network.data_subnet_ids
  security_group_id = module.security.db_security_group_id
  min_capacity      = 0
  max_capacity      = 2
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
| [aws_db_subnet_group.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/db_subnet_group) | resource |
| [aws_iam_role.monitoring](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy_attachment.monitoring](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_rds_cluster.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/rds_cluster) | resource |
| [aws_rds_cluster_instance.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/rds_cluster_instance) | resource |
| [aws_rds_cluster_parameter_group.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/rds_cluster_parameter_group) | resource |
| [random_id.final_snapshot](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/id) | resource |
| [aws_iam_policy_document.monitoring_assume](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |

### Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_name"></a> [name](#input\_name) | Name prefix for all resources (<project>-<environment>). | `string` | n/a | yes |
| <a name="input_security_group_id"></a> [security\_group\_id](#input\_security\_group\_id) | Security group attached to the cluster. | `string` | n/a | yes |
| <a name="input_subnet_ids"></a> [subnet\_ids](#input\_subnet\_ids) | Isolated data subnets (at least two AZs). | `list(string)` | n/a | yes |
| <a name="input_backup_retention_days"></a> [backup\_retention\_days](#input\_backup\_retention\_days) | Days to keep automated backups. | `number` | `7` | no |
| <a name="input_database_name"></a> [database\_name](#input\_database\_name) | Name of the initial database (schema). | `string` | `"reservations"` | no |
| <a name="input_deletion_protection"></a> [deletion\_protection](#input\_deletion\_protection) | Prevent the cluster from being deleted. | `bool` | `true` | no |
| <a name="input_engine_version"></a> [engine\_version](#input\_engine\_version) | Aurora PostgreSQL engine version (must support Serverless v2 scale to zero). | `string` | `"18.6"` | no |
| <a name="input_enhanced_monitoring_interval"></a> [enhanced\_monitoring\_interval](#input\_enhanced\_monitoring\_interval) | Enhanced Monitoring granularity in seconds (0 disables it). | `number` | `0` | no |
| <a name="input_instance_count"></a> [instance\_count](#input\_instance\_count) | Number of db.serverless instances: 1 = writer only, 2+ = writer plus reader(s) for Multi-AZ failover. | `number` | `1` | no |
| <a name="input_kms_key_arn"></a> [kms\_key\_arn](#input\_kms\_key\_arn) | Customer managed KMS key for storage, Performance Insights, the master secret and log groups. Null uses AWS managed keys. | `string` | `null` | no |
| <a name="input_log_retention_days"></a> [log\_retention\_days](#input\_log\_retention\_days) | Retention of the exported database log groups in days. | `number` | `30` | no |
| <a name="input_master_username"></a> [master\_username](#input\_master\_username) | Master user name. The password is managed by RDS in Secrets Manager. | `string` | `"app_admin"` | no |
| <a name="input_max_capacity"></a> [max\_capacity](#input\_max\_capacity) | Maximum Aurora Capacity Units. | `number` | `4` | no |
| <a name="input_min_capacity"></a> [min\_capacity](#input\_min\_capacity) | Minimum Aurora Capacity Units. 0 enables scale-to-zero (auto-pause) for idle environments. | `number` | `0.5` | no |
| <a name="input_parameter_group_family"></a> [parameter\_group\_family](#input\_parameter\_group\_family) | Cluster parameter group family matching engine\_version. | `string` | `"aurora-postgresql18"` | no |
| <a name="input_performance_insights_enabled"></a> [performance\_insights\_enabled](#input\_performance\_insights\_enabled) | Enable Performance Insights on the instances. | `bool` | `false` | no |
| <a name="input_port"></a> [port](#input\_port) | Database port. | `number` | `5432` | no |
| <a name="input_seconds_until_auto_pause"></a> [seconds\_until\_auto\_pause](#input\_seconds\_until\_auto\_pause) | Idle seconds before the cluster pauses (only when min\_capacity = 0). | `number` | `300` | no |
| <a name="input_skip_final_snapshot"></a> [skip\_final\_snapshot](#input\_skip\_final\_snapshot) | Skip the final snapshot on deletion (only for disposable environments). | `bool` | `false` | no |

### Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_cluster_arn"></a> [cluster\_arn](#output\_cluster\_arn) | ARN of the Aurora cluster. |
| <a name="output_cluster_identifier"></a> [cluster\_identifier](#output\_cluster\_identifier) | Identifier of the Aurora cluster (CloudWatch metric dimension). |
| <a name="output_database_name"></a> [database\_name](#output\_database\_name) | Name of the initial database. |
| <a name="output_endpoint"></a> [endpoint](#output\_endpoint) | Writer endpoint. |
| <a name="output_master_user_secret_arn"></a> [master\_user\_secret\_arn](#output\_master\_user\_secret\_arn) | ARN of the RDS-managed Secrets Manager secret with the master credentials. |
| <a name="output_port"></a> [port](#output\_port) | Database port. |
| <a name="output_reader_endpoint"></a> [reader\_endpoint](#output\_reader\_endpoint) | Load-balanced reader endpoint. |
<!-- END_TF_DOCS -->
