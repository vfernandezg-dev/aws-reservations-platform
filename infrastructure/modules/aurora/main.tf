locals {
  # Auto-pause is only valid when the cluster can scale to 0 ACU.
  scale_to_zero = var.min_capacity == 0
  # Aurora PostgreSQL writes connections, DDL and slow statements to the
  # "postgresql" log; failed IAM database authentications go to their own log.
  log_exports = ["postgresql", "iam-db-auth-error"]
}

resource "aws_db_subnet_group" "this" {
  name        = var.name
  description = "Isolated data subnets for ${var.name}"
  subnet_ids  = var.subnet_ids

  tags = {
    Name = var.name
  }
}

resource "aws_rds_cluster_parameter_group" "this" {
  name        = var.name
  family      = var.parameter_group_family
  description = "Cluster parameters for ${var.name}"

  # Reject unencrypted client connections.
  parameter {
    name  = "rds.force_ssl"
    value = "1"
  }

  # Audit trail: connections, disconnections and every DDL statement
  # (low volume, high value).
  parameter {
    name  = "log_connections"
    value = "1"
  }

  parameter {
    name  = "log_disconnections"
    value = "1"
  }

  parameter {
    name  = "log_statement"
    value = "ddl"
  }

  # Slow query log: statements slower than 2 seconds.
  parameter {
    name  = "log_min_duration_statement"
    value = "2000"
  }

  tags = {
    Name = var.name
  }
}

# Pre-create the log groups so their retention is managed by Terraform
# (otherwise RDS creates them with "never expire").
resource "aws_cloudwatch_log_group" "this" {
  for_each = toset(local.log_exports)

  name              = "/aws/rds/cluster/${var.name}/${each.key}"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.kms_key_arn
}

# Unique suffix so repeated create/destroy cycles never collide on the final
# snapshot name.
resource "random_id" "final_snapshot" {
  byte_length = 4
}

resource "aws_rds_cluster" "this" {
  #checkov:skip=CKV2_AWS_8:Automated backups with PITR are enabled; an AWS Backup plan is listed on the roadmap (cross-account copies).
  cluster_identifier = var.name
  engine             = "aurora-postgresql"
  engine_mode        = "provisioned"
  engine_version     = var.engine_version
  database_name      = var.database_name
  port               = var.port

  # The master password is generated and rotated by RDS in Secrets Manager:
  # it is never known to Terraform nor stored in state.
  master_username               = var.master_username
  manage_master_user_password   = true
  master_user_secret_kms_key_id = var.kms_key_arn

  db_subnet_group_name            = aws_db_subnet_group.this.name
  vpc_security_group_ids          = [var.security_group_id]
  db_cluster_parameter_group_name = aws_rds_cluster_parameter_group.this.name

  storage_encrypted                   = true
  kms_key_id                          = var.kms_key_arn
  iam_database_authentication_enabled = true

  serverlessv2_scaling_configuration {
    min_capacity             = var.min_capacity
    max_capacity             = var.max_capacity
    seconds_until_auto_pause = local.scale_to_zero ? var.seconds_until_auto_pause : null
  }

  backup_retention_period      = var.backup_retention_days
  preferred_backup_window      = "03:00-04:00"
  preferred_maintenance_window = "sun:04:30-sun:05:30"
  copy_tags_to_snapshot        = true
  deletion_protection          = var.deletion_protection
  skip_final_snapshot          = var.skip_final_snapshot
  final_snapshot_identifier    = var.skip_final_snapshot ? null : "${var.name}-final-${random_id.final_snapshot.hex}"

  enabled_cloudwatch_logs_exports = local.log_exports

  tags = {
    Name = var.name
  }

  depends_on = [aws_cloudwatch_log_group.this]
}

# Instance 1 is the writer; additional instances are readers in other AZs and
# become failover targets (Multi-AZ).
resource "aws_rds_cluster_instance" "this" {
  count = var.instance_count

  identifier                 = "${var.name}-${count.index + 1}"
  cluster_identifier         = aws_rds_cluster.this.id
  engine                     = aws_rds_cluster.this.engine
  engine_version             = aws_rds_cluster.this.engine_version
  instance_class             = "db.serverless"
  db_subnet_group_name       = aws_db_subnet_group.this.name
  publicly_accessible        = false
  auto_minor_version_upgrade = true
  copy_tags_to_snapshot      = true
  promotion_tier             = count.index
  monitoring_interval        = var.enhanced_monitoring_interval
  monitoring_role_arn        = var.enhanced_monitoring_interval > 0 ? aws_iam_role.monitoring[0].arn : null

  performance_insights_enabled    = var.performance_insights_enabled
  performance_insights_kms_key_id = var.performance_insights_enabled ? var.kms_key_arn : null

  tags = {
    Name = "${var.name}-${count.index + 1}"
  }
}

###############################################################################
# Enhanced Monitoring (OS-level metrics)
###############################################################################

data "aws_iam_policy_document" "monitoring_assume" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["monitoring.rds.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "monitoring" {
  count = var.enhanced_monitoring_interval > 0 ? 1 : 0

  name               = "${var.name}-rds-monitoring"
  assume_role_policy = data.aws_iam_policy_document.monitoring_assume.json
}

resource "aws_iam_role_policy_attachment" "monitoring" {
  count = var.enhanced_monitoring_interval > 0 ? 1 : 0

  role       = aws_iam_role.monitoring[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}
