# Internal ALB: not reachable from the internet. Its only client is the API
# Gateway VPC Link, and requests are forwarded only when they carry the secret
# header that CloudFront injects. Anything else gets a 403.

resource "aws_lb" "this" {
  #checkov:skip=CKV2_AWS_20:Internal ALB only reachable from the VPC Link; TLS terminates at CloudFront and API Gateway (see docs/adr/0003).
  name                       = var.name
  internal                   = true
  load_balancer_type         = "application"
  security_groups            = [var.security_group_id]
  subnets                    = var.subnet_ids
  drop_invalid_header_fields = true
  # "defensive" (AWS default) blocks severe and mitigates ambiguous HTTP desync
  # requests. "strictest" also rejects merely "acceptable" requests, which
  # includes the ones API Gateway sends through the VPC Link (HTTP 400).
  desync_mitigation_mode     = "defensive"
  enable_deletion_protection = var.deletion_protection
  idle_timeout               = 60

  dynamic "access_logs" {
    for_each = var.access_logs_bucket == null ? [] : [1]

    content {
      enabled = true
      bucket  = var.access_logs_bucket
      prefix  = var.access_logs_prefix
    }
  }

  tags = {
    Name = var.name
  }
}

resource "aws_lb_target_group" "app" {
  #checkov:skip=CKV_AWS_378:Hop between the internal ALB and tasks stays inside private subnets, restricted by security groups.
  name                 = "${var.name}-app"
  vpc_id               = var.vpc_id
  target_type          = "ip" # required for Fargate (awsvpc)
  protocol             = "HTTP"
  port                 = var.target_port
  deregistration_delay = 30

  health_check {
    enabled             = true
    path                = var.health_check_path
    matcher             = "200"
    interval            = 15
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }

  tags = {
    Name = "${var.name}-app"
  }
}

# trivy:ignore:AWS-0054 Internal listener; TLS terminates at CloudFront/API Gateway (docs/adr/0003).
resource "aws_lb_listener" "http" {
  #checkov:skip=CKV_AWS_2:Internal ALB, not internet-facing; only the VPC Link security group can reach it.
  #checkov:skip=CKV_AWS_103:No TLS listener on the internal ALB (see CKV_AWS_2).
  load_balancer_arn = aws_lb.this.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "fixed-response"

    fixed_response {
      content_type = "application/json"
      status_code  = "403"
      message_body = jsonencode({ message = "Forbidden" })
    }
  }

  tags = {
    Name = "${var.name}-http"
  }
}

resource "aws_lb_listener_rule" "origin_verified" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 10

  condition {
    http_header {
      http_header_name = var.origin_verify_header_name
      values           = [var.origin_verify_secret]
    }
  }

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }

  tags = {
    Name = "${var.name}-origin-verified"
  }
}
