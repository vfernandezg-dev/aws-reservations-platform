# Unit tests for modules/network. Run with `terraform test` (no AWS credentials
# needed: the AWS provider is mocked).

mock_provider "aws" {}

variables {
  name                 = "test"
  cidr_block           = "10.20.0.0/16"
  azs                  = ["us-east-1a", "us-east-1b"]
  flow_logs_bucket_arn = "arn:aws:s3:::test-logs"
}

run "three_tier_subnet_layout" {
  command = plan

  module {
    source = "./modules/network"
  }

  assert {
    condition     = aws_subnet.public["us-east-1a"].cidr_block == "10.20.0.0/24"
    error_message = "Public subnets must use the 10.x.0-9.0/24 range."
  }

  assert {
    condition     = aws_subnet.app["us-east-1b"].cidr_block == "10.20.11.0/24"
    error_message = "App subnets must use the 10.x.10-19.0/24 range."
  }

  assert {
    condition     = aws_subnet.data["us-east-1a"].cidr_block == "10.20.20.0/24"
    error_message = "Data subnets must use the 10.x.20-29.0/24 range."
  }

  assert {
    condition     = alltrue([for s in aws_subnet.public : s.map_public_ip_on_launch == false])
    error_message = "No subnet may auto-assign public IPs."
  }
}

run "nat_gateway_per_az_by_default" {
  command = plan

  module {
    source = "./modules/network"
  }

  assert {
    condition     = length(aws_nat_gateway.this) == 2
    error_message = "Expected one NAT gateway per AZ."
  }
}

run "single_nat_gateway_for_cost_saving" {
  command = plan

  module {
    source = "./modules/network"
  }

  variables {
    single_nat_gateway = true
  }

  assert {
    condition     = length(aws_nat_gateway.this) == 1
    error_message = "single_nat_gateway must create exactly one NAT gateway."
  }
}

run "data_tier_is_isolated" {
  command = apply # route table IDs are only known after (mocked) apply

  module {
    source = "./modules/network"
  }

  assert {
    condition     = length(aws_route_table_association.data) == 2
    error_message = "Every data subnet must use the isolated data route table."
  }

  assert {
    condition     = length(aws_route.app_nat) == 2
    error_message = "Each app route table must have exactly one default route (via NAT)."
  }

  assert {
    condition     = !contains([for r in aws_route.app_nat : r.route_table_id], aws_route_table.data.id)
    error_message = "The data route table must not have a default route."
  }
}

run "interface_endpoints_are_optional" {
  command = plan

  module {
    source = "./modules/network"
  }

  variables {
    interface_endpoint_services = ["ecr.api", "ecr.dkr", "logs"]
  }

  assert {
    condition     = length(aws_vpc_endpoint.interface) == 3
    error_message = "One interface endpoint per requested service expected."
  }

  assert {
    condition     = alltrue([for e in aws_vpc_endpoint.interface : e.private_dns_enabled])
    error_message = "Interface endpoints must enable private DNS, otherwise SDKs never use them."
  }
}

run "flow_logs_enabled_by_default" {
  command = plan

  module {
    source = "./modules/network"
  }

  assert {
    condition     = length(aws_flow_log.this) == 1 && aws_flow_log.this[0].traffic_type == "ALL"
    error_message = "VPC Flow Logs must capture all traffic by default."
  }
}

run "flow_logs_require_a_bucket" {
  command = plan

  module {
    source = "./modules/network"
  }

  variables {
    flow_logs_bucket_arn = null
  }

  expect_failures = [var.flow_logs_bucket_arn]
}

run "rejects_non_slash_16_cidr" {
  command = plan

  module {
    source = "./modules/network"
  }

  variables {
    cidr_block = "10.20.0.0/20"
  }

  expect_failures = [var.cidr_block]
}
