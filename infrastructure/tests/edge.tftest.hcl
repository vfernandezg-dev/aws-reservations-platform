# Edge security controls: internal ALB, WAF and CloudFront.

mock_provider "aws" {}

variables {
  name                 = "test"
  origin_verify_secret = "abcdefghijklmnopqrstuvwxyz0123456789ABCD"
}

run "alb_rejects_requests_without_origin_secret" {
  command = plan

  module {
    source = "./modules/alb"
  }

  variables {
    vpc_id            = "vpc-0123456789abcdef0"
    subnet_ids        = ["subnet-a", "subnet-b"]
    security_group_id = "sg-0123456789abcdef0"
  }

  assert {
    condition     = aws_lb.this.internal
    error_message = "The ALB must be internal."
  }

  assert {
    condition     = aws_lb_listener.http.default_action[0].fixed_response[0].status_code == "403"
    error_message = "Requests without the origin secret must get 403."
  }

  assert {
    condition     = aws_lb.this.drop_invalid_header_fields
    error_message = "Invalid HTTP headers must be dropped."
  }

  assert {
    condition     = aws_lb.this.desync_mitigation_mode == "defensive"
    error_message = "Use 'defensive' desync mitigation: 'strictest' rejects requests coming from API Gateway."
  }
}

run "alb_rejects_weak_origin_secret" {
  command = plan

  module {
    source = "./modules/alb"
  }

  variables {
    vpc_id               = "vpc-0123456789abcdef0"
    subnet_ids           = ["subnet-a", "subnet-b"]
    security_group_id    = "sg-0123456789abcdef0"
    origin_verify_secret = "short*secret"
  }

  expect_failures = [var.origin_verify_secret]
}

run "waf_is_global_and_logs_correctly" {
  command = plan

  module {
    source = "./modules/waf"
  }

  assert {
    condition     = aws_wafv2_web_acl.this.scope == "CLOUDFRONT" && aws_wafv2_web_acl.this.region == "us-east-1"
    error_message = "CloudFront Web ACLs must be created in us-east-1 with CLOUDFRONT scope."
  }

  assert {
    condition     = startswith(aws_cloudwatch_log_group.this[0].name, "aws-waf-logs-")
    error_message = "WAF log groups must be prefixed with aws-waf-logs-."
  }
}

run "cloudfront_routes_api_without_host_header" {
  command = plan

  module {
    source = "./modules/cdn"
  }

  variables {
    static_bucket_id                   = "test-static"
    static_bucket_arn                  = "arn:aws:s3:::test-static"
    static_bucket_regional_domain_name = "test-static.s3.us-east-1.amazonaws.com"
    api_endpoint                       = "https://abc123.execute-api.us-east-1.amazonaws.com"
    web_acl_arn                        = "arn:aws:wafv2:us-east-1:123456789012:global/webacl/test/0123"
    enable_access_logs                 = false
  }

  assert {
    condition     = aws_cloudfront_distribution.this.ordered_cache_behavior[0].path_pattern == "/api/*"
    error_message = "/api/* must be routed to API Gateway."
  }

  assert {
    condition     = aws_cloudfront_distribution.this.ordered_cache_behavior[0].origin_request_policy_id == data.aws_cloudfront_origin_request_policy.all_viewer_except_host.id
    error_message = "API requests must not forward the viewer Host header."
  }

  assert {
    condition     = aws_cloudfront_distribution.this.web_acl_id == "arn:aws:wafv2:us-east-1:123456789012:global/webacl/test/0123"
    error_message = "The WAF Web ACL must be attached."
  }

  assert {
    condition     = length(aws_cloudwatch_log_delivery.this) == 0
    error_message = "No log delivery when access logs are disabled."
  }
}

run "cloudfront_custom_domain_needs_certificate" {
  command = plan

  module {
    source = "./modules/cdn"
  }

  variables {
    static_bucket_id                   = "test-static"
    static_bucket_arn                  = "arn:aws:s3:::test-static"
    static_bucket_regional_domain_name = "test-static.s3.us-east-1.amazonaws.com"
    api_endpoint                       = "https://abc123.execute-api.us-east-1.amazonaws.com"
    web_acl_arn                        = "arn:aws:wafv2:us-east-1:123456789012:global/webacl/test/0123"
    enable_access_logs                 = false
    aliases                            = ["app.example.com"]
  }

  expect_failures = [var.aliases]
}
