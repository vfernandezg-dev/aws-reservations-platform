mock_provider "aws" {
  # The provider validates policy JSON even when mocked.
  mock_data "aws_iam_policy_document" {
    defaults = {
      json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}"
    }
  }

  mock_data "aws_region" {
    defaults = {
      region = "us-east-1"
    }
  }
}

variables {
  name                    = "test"
  image                   = "123456789012.dkr.ecr.us-east-1.amazonaws.com/reservations-app:abc1234"
  image_tag               = "abc1234"
  subnet_ids              = ["subnet-a", "subnet-b"]
  security_group_id       = "sg-0123456789abcdef0"
  target_group_arn        = "arn:aws:elasticloadbalancing:us-east-1:123456789012:targetgroup/test-app/0123456789abcdef"
  alb_arn_suffix          = "app/test/0123456789abcdef"
  target_group_arn_suffix = "targetgroup/test-app/0123456789abcdef"
  db_host                 = "test.cluster-abc.us-east-1.rds.amazonaws.com"
  db_name                 = "reservations"
  db_secret_arn           = "arn:aws:secretsmanager:us-east-1:123456789012:secret:rds!cluster-test"
}

run "hardened_fargate_task" {
  command = plan

  module {
    source = "./modules/ecs"
  }

  assert {
    condition     = aws_ecs_task_definition.app.runtime_platform[0].cpu_architecture == "ARM64"
    error_message = "Tasks must run on Graviton (ARM64)."
  }

  assert {
    condition     = jsondecode(aws_ecs_task_definition.app.container_definitions)[0].readonlyRootFilesystem
    error_message = "Container root filesystem must be read-only."
  }

  assert {
    condition = !contains(
      [for e in jsondecode(aws_ecs_task_definition.app.container_definitions)[0].environment : e.name],
      "DB_PASSWORD"
    )
    error_message = "The DB password must come from Secrets Manager, never from plain environment variables."
  }

  assert {
    condition = contains(
      [for s in jsondecode(aws_ecs_task_definition.app.container_definitions)[0].secrets : s.name],
      "DB_PASSWORD"
    )
    error_message = "The DB password must be injected as an ECS secret."
  }
}

run "private_service_with_safe_deployments" {
  command = plan

  module {
    source = "./modules/ecs"
  }

  assert {
    condition     = aws_ecs_service.app.network_configuration[0].assign_public_ip == false
    error_message = "Tasks must not get public IPs."
  }

  assert {
    condition     = aws_ecs_service.app.deployment_circuit_breaker[0].enable && aws_ecs_service.app.deployment_circuit_breaker[0].rollback
    error_message = "Failed deployments must roll back automatically."
  }
}

run "fargate_spot_for_non_production" {
  command = plan

  module {
    source = "./modules/ecs"
  }

  variables {
    use_fargate_spot = true
  }

  assert {
    condition     = one(aws_ecs_service.app.capacity_provider_strategy).capacity_provider == "FARGATE_SPOT"
    error_message = "use_fargate_spot must schedule tasks on FARGATE_SPOT."
  }
}
