mock_provider "aws" {}

variables {
  name   = "test"
  vpc_id = "vpc-0123456789abcdef0"
}

run "nothing_is_open_to_the_internet" {
  command = plan

  module {
    source = "./modules/security"
  }

  assert {
    condition = alltrue([
      for rule in [
        aws_vpc_security_group_ingress_rule.alb_from_vpc_link,
        aws_vpc_security_group_ingress_rule.app_from_alb,
        aws_vpc_security_group_ingress_rule.db_from_app,
      ] : rule.cidr_ipv4 == null && rule.cidr_ipv6 == null
    ])
    error_message = "Ingress must only reference other security groups, never CIDR ranges."
  }
}

run "tiers_are_chained_by_security_group" {
  command = apply

  module {
    source = "./modules/security"
  }

  assert {
    condition     = aws_vpc_security_group_ingress_rule.app_from_alb.referenced_security_group_id == aws_security_group.alb.id
    error_message = "Tasks must only accept traffic from the ALB."
  }

  assert {
    condition     = aws_vpc_security_group_ingress_rule.db_from_app.referenced_security_group_id == aws_security_group.app.id
    error_message = "Aurora must only accept traffic from the tasks."
  }

  assert {
    condition     = aws_vpc_security_group_ingress_rule.db_from_app.from_port == 5432
    error_message = "Database ingress must be limited to the PostgreSQL port."
  }
}
