# Security groups are created together in one module so the SG -> SG references
# below never form a cycle between modules. Every hop is explicit:
#
#   VPC Link --80--> ALB --app_port--> ECS tasks --db_port (5432)--> PostgreSQL

resource "aws_security_group" "vpc_link" {
  #checkov:skip=CKV2_AWS_5:Attached in another module (passed as an input); the scanner cannot follow module outputs.
  name        = "${var.name}-vpc-link"
  description = "API Gateway VPC Link ENIs"
  vpc_id      = var.vpc_id

  tags = {
    Name = "${var.name}-vpc-link"
  }
}

resource "aws_security_group" "alb" {
  #checkov:skip=CKV2_AWS_5:Attached in another module (passed as an input); the scanner cannot follow module outputs.
  name        = "${var.name}-alb"
  description = "Internal Application Load Balancer"
  vpc_id      = var.vpc_id

  tags = {
    Name = "${var.name}-alb"
  }
}

resource "aws_security_group" "app" {
  #checkov:skip=CKV2_AWS_5:Attached in another module (passed as an input); the scanner cannot follow module outputs.
  name        = "${var.name}-app"
  description = "ECS Fargate tasks"
  vpc_id      = var.vpc_id

  tags = {
    Name = "${var.name}-app"
  }
}

# The database is the stateful tier: name_prefix + create_before_destroy let
# Terraform replace this group (e.g. a new description) while RDS keeps
# running, by attaching the new group before deleting the old one.
resource "aws_security_group" "db" {
  #checkov:skip=CKV2_AWS_5:Attached in another module (passed as an input); the scanner cannot follow module outputs.
  name_prefix = "${var.name}-db-"
  description = "RDS for PostgreSQL"
  vpc_id      = var.vpc_id

  tags = {
    Name = "${var.name}-db"
  }

  lifecycle {
    create_before_destroy = true
  }
}

###############################################################################
# VPC Link -> ALB
###############################################################################

resource "aws_vpc_security_group_egress_rule" "vpc_link_to_alb" {
  security_group_id            = aws_security_group.vpc_link.id
  description                  = "HTTP to the internal ALB"
  ip_protocol                  = "tcp"
  from_port                    = 80
  to_port                      = 80
  referenced_security_group_id = aws_security_group.alb.id
}

resource "aws_vpc_security_group_ingress_rule" "alb_from_vpc_link" {
  #checkov:skip=CKV_AWS_260:False positive: the source is the VPC Link security group, not 0.0.0.0/0.
  security_group_id            = aws_security_group.alb.id
  description                  = "HTTP from the API Gateway VPC Link"
  ip_protocol                  = "tcp"
  from_port                    = 80
  to_port                      = 80
  referenced_security_group_id = aws_security_group.vpc_link.id
}

###############################################################################
# ALB -> app
###############################################################################

resource "aws_vpc_security_group_egress_rule" "alb_to_app" {
  security_group_id            = aws_security_group.alb.id
  description                  = "Traffic and health checks to ECS tasks"
  ip_protocol                  = "tcp"
  from_port                    = var.app_port
  to_port                      = var.app_port
  referenced_security_group_id = aws_security_group.app.id
}

resource "aws_vpc_security_group_ingress_rule" "app_from_alb" {
  security_group_id            = aws_security_group.app.id
  description                  = "Traffic from the internal ALB"
  ip_protocol                  = "tcp"
  from_port                    = var.app_port
  to_port                      = var.app_port
  referenced_security_group_id = aws_security_group.alb.id
}

###############################################################################
# app -> PostgreSQL and AWS APIs
###############################################################################

resource "aws_vpc_security_group_egress_rule" "app_to_db" {
  security_group_id            = aws_security_group.app.id
  description                  = "PostgreSQL to the database"
  ip_protocol                  = "tcp"
  from_port                    = var.db_port
  to_port                      = var.db_port
  referenced_security_group_id = aws_security_group.db.id
}

# Tasks need HTTPS to AWS APIs (ECR, CloudWatch Logs, Secrets Manager), via NAT
# or interface endpoints. Destinations are AWS public endpoints, hence 0.0.0.0/0.
resource "aws_vpc_security_group_egress_rule" "app_https" {
  security_group_id = aws_security_group.app.id
  description       = "HTTPS to AWS service endpoints"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_ingress_rule" "db_from_app" {
  security_group_id            = aws_security_group.db.id
  description                  = "PostgreSQL from ECS tasks"
  ip_protocol                  = "tcp"
  from_port                    = var.db_port
  to_port                      = var.db_port
  referenced_security_group_id = aws_security_group.app.id
}
