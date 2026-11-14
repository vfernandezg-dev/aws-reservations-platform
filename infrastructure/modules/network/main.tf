locals {
  # Stable AZ -> index map so subnets are keyed by AZ name (for_each) instead
  # of list position (count), which avoids resource churn if the list changes.
  az_index = { for idx, az in var.azs : az => idx }

  # /16 VPC -> /24 subnets. Offsets keep each tier in its own, readable range:
  #   public 10.x.0-9.0/24 · app 10.x.10-19.0/24 · data 10.x.20-29.0/24
  public_subnets = { for az, idx in local.az_index : az => cidrsubnet(var.cidr_block, 8, idx) }
  app_subnets    = { for az, idx in local.az_index : az => cidrsubnet(var.cidr_block, 8, idx + 10) }
  data_subnets   = { for az, idx in local.az_index : az => cidrsubnet(var.cidr_block, 8, idx + 20) }

  # One NAT gateway per AZ for HA, or a single shared one to save cost.
  nat_azs = var.single_nat_gateway ? [var.azs[0]] : var.azs
}

data "aws_region" "current" {}

###############################################################################
# VPC
###############################################################################

resource "aws_vpc" "this" {
  cidr_block           = var.cidr_block
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = var.name
  }
}

# Strip every rule from the default security group so nothing can use it by
# accident.
resource "aws_default_security_group" "this" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name = "${var.name}-default-deny"
  }
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name = var.name
  }
}

###############################################################################
# Subnets
###############################################################################

# Public tier: only NAT gateways live here. No workload is internet-facing;
# ingress comes through CloudFront -> API Gateway -> VPC Link.
resource "aws_subnet" "public" {
  for_each = local.public_subnets

  vpc_id                  = aws_vpc.this.id
  availability_zone       = each.key
  cidr_block              = each.value
  map_public_ip_on_launch = false

  tags = {
    Name = "${var.name}-public-${each.key}"
    Tier = "public"
  }
}

resource "aws_subnet" "app" {
  for_each = local.app_subnets

  vpc_id            = aws_vpc.this.id
  availability_zone = each.key
  cidr_block        = each.value

  tags = {
    Name = "${var.name}-app-${each.key}"
    Tier = "app"
  }
}

resource "aws_subnet" "data" {
  for_each = local.data_subnets

  vpc_id            = aws_vpc.this.id
  availability_zone = each.key
  cidr_block        = each.value

  tags = {
    Name = "${var.name}-data-${each.key}"
    Tier = "data"
  }
}

###############################################################################
# NAT gateways
###############################################################################

resource "aws_eip" "nat" {
  for_each = toset(local.nat_azs)

  domain = "vpc"

  tags = {
    Name = "${var.name}-nat-${each.key}"
  }

  depends_on = [aws_internet_gateway.this]
}

resource "aws_nat_gateway" "this" {
  for_each = toset(local.nat_azs)

  allocation_id = aws_eip.nat[each.key].id
  subnet_id     = aws_subnet.public[each.key].id

  tags = {
    Name = "${var.name}-${each.key}"
  }
}

###############################################################################
# Routing
###############################################################################

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name = "${var.name}-public"
  }
}

resource "aws_route" "public_internet" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.this.id
}

resource "aws_route_table_association" "public" {
  for_each = aws_subnet.public

  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}

# App tier: one route table per AZ, egress through the NAT gateway of the same
# AZ (or the single shared one).
resource "aws_route_table" "app" {
  for_each = local.az_index

  vpc_id = aws_vpc.this.id

  tags = {
    Name = "${var.name}-app-${each.key}"
  }
}

resource "aws_route" "app_nat" {
  for_each = local.az_index

  route_table_id         = aws_route_table.app[each.key].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.this[var.single_nat_gateway ? var.azs[0] : each.key].id
}

resource "aws_route_table_association" "app" {
  for_each = aws_subnet.app

  subnet_id      = each.value.id
  route_table_id = aws_route_table.app[each.key].id
}

# Data tier: isolated, no route to the internet at all.
resource "aws_route_table" "data" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name = "${var.name}-data"
  }
}

resource "aws_route_table_association" "data" {
  for_each = aws_subnet.data

  subnet_id      = each.value.id
  route_table_id = aws_route_table.data.id
}

###############################################################################
# VPC endpoints
###############################################################################

# Free gateway endpoint: S3 traffic (including ECR image layers) stays on the
# AWS network and skips NAT data-processing charges.
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.this.id
  service_name      = "com.amazonaws.${data.aws_region.current.region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [for rt in aws_route_table.app : rt.id]

  tags = {
    Name = "${var.name}-s3"
  }
}

resource "aws_security_group" "endpoints" {
  count = length(var.interface_endpoint_services) > 0 ? 1 : 0

  name        = "${var.name}-vpc-endpoints"
  description = "HTTPS from inside the VPC to interface endpoints"
  vpc_id      = aws_vpc.this.id

  tags = {
    Name = "${var.name}-vpc-endpoints"
  }
}

resource "aws_vpc_security_group_ingress_rule" "endpoints_https" {
  count = length(var.interface_endpoint_services) > 0 ? 1 : 0

  security_group_id = aws_security_group.endpoints[0].id
  description       = "HTTPS from the VPC"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  cidr_ipv4         = aws_vpc.this.cidr_block
}

# Optional interface endpoints (ECR, Logs, Secrets Manager, ...). Recommended
# for production: private connectivity to AWS APIs without traversing NAT.
resource "aws_vpc_endpoint" "interface" {
  for_each = toset(var.interface_endpoint_services)

  vpc_id              = aws_vpc.this.id
  service_name        = "com.amazonaws.${data.aws_region.current.region}.${each.key}"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true
  subnet_ids          = [for s in aws_subnet.app : s.id]
  security_group_ids  = [aws_security_group.endpoints[0].id]

  tags = {
    Name = "${var.name}-${each.key}"
  }
}

###############################################################################
# Flow logs
###############################################################################

resource "aws_flow_log" "this" {
  count = var.enable_flow_logs ? 1 : 0

  vpc_id                   = aws_vpc.this.id
  traffic_type             = "ALL"
  log_destination_type     = "s3"
  log_destination          = "${var.flow_logs_bucket_arn}/vpc-flow-logs/"
  max_aggregation_interval = 600

  destination_options {
    file_format                = "parquet"
    hive_compatible_partitions = true
    per_hour_partition         = true
  }

  tags = {
    Name = var.name
  }
}
