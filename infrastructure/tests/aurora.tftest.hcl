mock_provider "aws" {
  # The provider validates policy JSON even when mocked.
  mock_data "aws_iam_policy_document" {
    defaults = {
      json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}"
    }
  }

  # Computed nested blocks are empty in mocks; give the managed secret a value.
  mock_resource "aws_rds_cluster" {
    defaults = {
      master_user_secret = [{
        secret_arn    = "arn:aws:secretsmanager:us-east-1:123456789012:secret:rds!cluster-test"
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
    source = "./modules/aurora"
  }

  variables {
    min_capacity                 = 0.5
    max_capacity                 = 8
    instance_count               = 2
    deletion_protection          = true
    skip_final_snapshot          = false
    performance_insights_enabled = true
    enhanced_monitoring_interval = 60
  }

  assert {
    condition     = length(aws_rds_cluster_instance.this) == 2
    error_message = "Production needs a writer and a reader (Multi-AZ failover)."
  }

  assert {
    condition     = aws_rds_cluster.this.deletion_protection && aws_rds_cluster.this.storage_encrypted
    error_message = "Production cluster must be encrypted and deletion protected."
  }

  assert {
    condition     = aws_rds_cluster.this.manage_master_user_password && aws_rds_cluster.this.master_password == null
    error_message = "The master password must be managed by RDS (never in Terraform state)."
  }

  assert {
    condition     = startswith(aws_rds_cluster.this.final_snapshot_identifier, "test-final-")
    error_message = "A uniquely named final snapshot must be taken on deletion."
  }

  assert {
    condition     = aws_rds_cluster.this.serverlessv2_scaling_configuration[0].min_capacity >= 0.5
    error_message = "Production must keep a warm minimum capacity (no auto-pause)."
  }

  assert {
    condition     = contains(aws_rds_cluster.this.enabled_cloudwatch_logs_exports, "audit")
    error_message = "Audit logs must be exported."
  }

  assert {
    condition     = length(aws_iam_role.monitoring) == 1
    error_message = "Enhanced Monitoring needs its IAM role."
  }
}

run "dev_scales_to_zero" {
  command = plan

  module {
    source = "./modules/aurora"
  }

  variables {
    min_capacity        = 0
    max_capacity        = 2
    deletion_protection = false
    skip_final_snapshot = true
  }

  assert {
    condition     = aws_rds_cluster.this.serverlessv2_scaling_configuration[0].min_capacity == 0
    error_message = "Dev must be able to scale to 0 ACU."
  }

  assert {
    condition     = aws_rds_cluster.this.serverlessv2_scaling_configuration[0].seconds_until_auto_pause == 300
    error_message = "Auto-pause must be configured when scaling to zero."
  }

  assert {
    condition     = length(aws_rds_cluster_instance.this) == 1
    error_message = "Dev runs a single (writer) instance."
  }
}

run "rejects_inverted_capacity" {
  command = plan

  module {
    source = "./modules/aurora"
  }

  variables {
    min_capacity = 4
    max_capacity = 2
  }

  expect_failures = [var.max_capacity]
}
