locals {
  # PostgreSQL log (connections, DDL, slow statements) and failed IAM
  # database authentications.
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

resource "aws_db_parameter_group" "this" {
  name        = "${var.name}-instance"
  family      = var.parameter_group_family
  description = "PostgreSQL parameters for ${var.name}"

  # Reject unencrypted client connections. RDS reports this parameter as
  # "pending-reboot"; declaring it avoids a perpetual diff.
  parameter {
    name         = "rds.force_ssl"
    value        = "1"
    apply_method = "pending-reboot"
  }

  # Audit trail: every connection stage (PostgreSQL 18 takes a list:
  # receipt, authentication, authorization, setup_durations or all),
  # disconnections and every DDL statement. Low volume, high value.
  parameter {
    name  = "log_connections"
    value = "all"
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
    Name = "${var.name}-instance"
  }
}

# Pre-create the log groups so their retention and encryption are managed by
# Terraform (otherwise RDS creates them with "never expire").
resource "aws_cloudwatch_log_group" "this" {
  for_each = toset(local.log_exports)

  name              = "/aws/rds/instance/${var.name}/${each.key}"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.kms_key_arn
}

# Unique suffix so repeated create/destroy cycles never collide on the final
# snapshot name.
resource "random_id" "final_snapshot" {
  byte_length = 4
}

resource "aws_db_instance" "this" {
  identifier     = var.name
  engine         = "postgres"
  engine_version = var.engine_version
  instance_class = var.instance_class
  db_name        = var.database_name
  port           = var.port

  # The master password is generated and rotated by RDS in Secrets Manager:
  # it is never known to Terraform nor stored in state.
  username                      = var.master_username
  manage_master_user_password   = true
  master_user_secret_kms_key_id = var.kms_key_arn

  allocated_storage     = var.allocated_storage
  max_allocated_storage = var.max_allocated_storage
  storage_type          = "gp3"
  storage_encrypted     = true
  kms_key_id            = var.kms_key_arn

  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [var.security_group_id]
  parameter_group_name   = aws_db_parameter_group.this.name
  publicly_accessible    = false
  network_type           = "IPV4"
  ca_cert_identifier     = "rds-ca-rsa2048-g1"

  # Synchronous standby in a second AZ with automatic failover.
  multi_az                            = var.multi_az
  iam_database_authentication_enabled = true
  auto_minor_version_upgrade          = true

  backup_retention_period   = var.backup_retention_days
  backup_window             = "03:00-04:00"
  maintenance_window        = "sun:04:30-sun:05:30"
  copy_tags_to_snapshot     = true
  delete_automated_backups  = !var.deletion_protection
  deletion_protection       = var.deletion_protection
  skip_final_snapshot       = var.skip_final_snapshot
  final_snapshot_identifier = var.skip_final_snapshot ? null : "${var.name}-final-${random_id.final_snapshot.hex}"

  enabled_cloudwatch_logs_exports = local.log_exports

  monitoring_interval = var.enhanced_monitoring_interval
  monitoring_role_arn = var.enhanced_monitoring_interval > 0 ? aws_iam_role.monitoring[0].arn : null

  performance_insights_enabled          = var.performance_insights_enabled
  performance_insights_kms_key_id       = var.performance_insights_enabled ? var.kms_key_arn : null
  performance_insights_retention_period = var.performance_insights_enabled ? 7 : null

  tags = {
    Name = var.name
  }

  depends_on = [aws_cloudwatch_log_group.this]
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
