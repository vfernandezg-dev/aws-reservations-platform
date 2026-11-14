mock_provider "aws" {
  # The provider validates policy JSON even when mocked.
  mock_data "aws_iam_policy_document" {
    defaults = {
      json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}"
    }
  }

  # aws_db_instance validates the Enhanced Monitoring role ARN.
  mock_resource "aws_iam_role" {
    defaults = {
      arn = "arn:aws:iam::123456789012:role/test-rds-monitoring"
    }
  }

  # Computed nested blocks are empty in mocks; give the managed secret a value.
  mock_resource "aws_db_instance" {
    defaults = {
      master_user_secret = [{
        secret_arn    = "arn:aws:secretsmanager:us-east-1:123456789012:secret:rds!db-test"
        kms_key_id    = "arn:aws:kms:us-east-1:123456789012:key/test"
        secret_status = "active"
      }]
    }
  }
}

variables {
  name              = "test"
  subnet_ids        = ["subnet-a", "subnet-b"]
  security_group_id = "sg-0123456789abcdef0"
}

run "production_profile" {
  command = apply

  module {
    source = "./modules/database"
  }

  variables {
    instance_class               = "db.t4g.small"
    multi_az                     = true
    deletion_protection          = true
    skip_final_snapshot          = false
    performance_insights_enabled = true
    enhanced_monitoring_interval = 60
  }

  assert {
    condition     = aws_db_instance.this.multi_az && aws_db_instance.this.deletion_protection
    error_message = "Production needs a Multi-AZ standby and deletion protection."
  }

  assert {
    condition     = aws_db_instance.this.storage_encrypted && !aws_db_instance.this.publicly_accessible
    error_message = "The database must be encrypted and private."
  }

  assert {
    condition     = aws_db_instance.this.manage_master_user_password && aws_db_instance.this.password == null
    error_message = "The master password must be managed by RDS (never in Terraform state)."
  }

  assert {
    condition     = startswith(aws_db_instance.this.final_snapshot_identifier, "test-final-")
    error_message = "A uniquely named final snapshot must be taken on deletion."
  }

  assert {
    condition     = aws_db_instance.this.engine == "postgres" && aws_db_instance.this.port == 5432
    error_message = "The instance must run PostgreSQL on port 5432."
  }

  assert {
    condition     = contains(aws_db_instance.this.enabled_cloudwatch_logs_exports, "postgresql")
    error_message = "PostgreSQL logs (connections, DDL, slow statements) must be exported."
  }

  assert {
    condition     = length(aws_iam_role.monitoring) == 1
    error_message = "Enhanced Monitoring needs its IAM role."
  }
}

run "tls_and_audit_parameters" {
  command = plan

  module {
    source = "./modules/database"
  }

  assert {
    condition = alltrue([
      contains([for p in aws_db_parameter_group.this.parameter : "${p.name}=${p.value}"], "rds.force_ssl=1"),
      contains([for p in aws_db_parameter_group.this.parameter : "${p.name}=${p.value}"], "log_connections=all"),
      contains([for p in aws_db_parameter_group.this.parameter : "${p.name}=${p.value}"], "log_statement=ddl"),
    ])
    error_message = "TLS must be enforced and connections/DDL must be logged."
  }
}

run "dev_profile" {
  command = plan

  module {
    source = "./modules/database"
  }

  variables {
    deletion_protection = false
    skip_final_snapshot = true
  }

  assert {
    condition     = !aws_db_instance.this.multi_az && aws_db_instance.this.instance_class == "db.t4g.micro"
    error_message = "Dev runs a single small Graviton instance."
  }

  assert {
    condition     = aws_db_instance.this.final_snapshot_identifier == null
    error_message = "Disposable environments skip the final snapshot."
  }
}

run "rejects_storage_limit_below_allocation" {
  command = plan

  module {
    source = "./modules/database"
  }

  variables {
    allocated_storage     = 50
    max_allocated_storage = 30
  }

  expect_failures = [var.max_allocated_storage]
}
