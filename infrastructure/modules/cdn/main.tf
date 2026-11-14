locals {
  s3_origin_id  = "s3-static"
  api_origin_id = "api-gateway"

  # HTTP API endpoint looks like https://abc123.execute-api.us-east-1.amazonaws.com
  api_domain_name = trimprefix(var.api_endpoint, "https://")

  use_custom_domain = var.acm_certificate_arn != null
}

###############################################################################
# AWS managed policies (looked up by name, no hard-coded IDs)
###############################################################################

data "aws_cloudfront_cache_policy" "caching_optimized" {
  name = "Managed-CachingOptimized"
}

data "aws_cloudfront_cache_policy" "caching_disabled" {
  name = "Managed-CachingDisabled"
}

# Forward everything the API needs (Authorization, query strings, cookies)
# EXCEPT the viewer Host header: API Gateway rejects a foreign Host with 403.
data "aws_cloudfront_origin_request_policy" "all_viewer_except_host" {
  name = "Managed-AllViewerExceptHostHeader"
}

data "aws_cloudfront_response_headers_policy" "security_headers" {
  name = "Managed-SecurityHeadersPolicy"
}

###############################################################################
# Distribution
###############################################################################

resource "aws_cloudfront_origin_access_control" "s3" {
  name                              = "${var.name}-s3"
  description                       = "OAC for the ${var.name} static bucket"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_cloudfront_distribution" "this" {
  #checkov:skip=CKV_AWS_86:Access logs use CloudFront standard logging v2 (aws_cloudwatch_log_delivery below), not the legacy logging_config.
  #checkov:skip=CKV_AWS_374:Geo blocking is enforced by the WAF Web ACL (var.blocked_country_codes) where needed.
  #checkov:skip=CKV_AWS_310:Single-region deployment; origin failover is part of the multi-region roadmap.
  #checkov:skip=CKV2_AWS_47:The attached Web ACL includes AWSManagedRulesKnownBadInputsRuleSet (Log4j); the check cannot follow the module input.
  comment             = "${var.name} - static site (S3) + API (/api/*)"
  enabled             = true
  is_ipv6_enabled     = true
  http_version        = "http2and3"
  price_class         = var.price_class
  default_root_object = "index.html"
  web_acl_id          = var.web_acl_arn
  aliases             = var.aliases

  origin {
    origin_id                = local.s3_origin_id
    domain_name              = var.static_bucket_regional_domain_name
    origin_access_control_id = aws_cloudfront_origin_access_control.s3.id
  }

  origin {
    origin_id   = local.api_origin_id
    domain_name = local.api_domain_name

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "https-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }

    # Shared secret checked by the internal ALB. Only CloudFront knows it, so
    # calling the execute-api URL directly (bypassing WAF) is rejected.
    custom_header {
      name  = var.origin_verify_header_name
      value = var.origin_verify_secret
    }
  }

  default_cache_behavior {
    target_origin_id           = local.s3_origin_id
    viewer_protocol_policy     = "redirect-to-https"
    allowed_methods            = ["GET", "HEAD", "OPTIONS"]
    cached_methods             = ["GET", "HEAD"]
    compress                   = true
    cache_policy_id            = data.aws_cloudfront_cache_policy.caching_optimized.id
    response_headers_policy_id = data.aws_cloudfront_response_headers_policy.security_headers.id
  }

  ordered_cache_behavior {
    path_pattern               = "/api/*"
    target_origin_id           = local.api_origin_id
    viewer_protocol_policy     = "https-only"
    allowed_methods            = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods             = ["GET", "HEAD"]
    compress                   = true
    cache_policy_id            = data.aws_cloudfront_cache_policy.caching_disabled.id
    origin_request_policy_id   = data.aws_cloudfront_origin_request_policy.all_viewer_except_host.id
    response_headers_policy_id = data.aws_cloudfront_response_headers_policy.security_headers.id
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = !local.use_custom_domain
    acm_certificate_arn            = var.acm_certificate_arn
    ssl_support_method             = local.use_custom_domain ? "sni-only" : null
    minimum_protocol_version       = local.use_custom_domain ? "TLSv1.2_2021" : null
  }

  tags = {
    Name = var.name
  }
}

###############################################################################
# Static bucket policy: only this distribution (via OAC) may read objects.
# It lives here, not in the storage module, because it needs the
# distribution ARN (avoids a storage <-> cdn dependency cycle).
###############################################################################

data "aws_iam_policy_document" "static_bucket" {
  statement {
    sid       = "AllowCloudFrontOAC"
    actions   = ["s3:GetObject"]
    resources = ["${var.static_bucket_arn}/*"]

    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [aws_cloudfront_distribution.this.arn]
    }
  }

  statement {
    sid       = "DenyInsecureTransport"
    effect    = "Deny"
    actions   = ["s3:*"]
    resources = [var.static_bucket_arn, "${var.static_bucket_arn}/*"]

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

resource "aws_s3_bucket_policy" "static" {
  bucket = var.static_bucket_id
  policy = data.aws_iam_policy_document.static_bucket.json
}

###############################################################################
# Standard logging v2 (CloudWatch vended logs -> S3, no bucket ACLs needed).
# CloudFront is global; its log delivery resources live in us-east-1.
###############################################################################

resource "aws_cloudwatch_log_delivery_source" "this" {
  count = var.enable_access_logs ? 1 : 0

  region       = "us-east-1"
  name         = "${var.name}-cloudfront"
  log_type     = "ACCESS_LOGS"
  resource_arn = aws_cloudfront_distribution.this.arn
}

resource "aws_cloudwatch_log_delivery_destination" "this" {
  count = var.enable_access_logs ? 1 : 0

  region        = "us-east-1"
  name          = "${var.name}-cloudfront-s3"
  output_format = "json"

  delivery_destination_configuration {
    destination_resource_arn = var.log_bucket_arn
  }
}

resource "aws_cloudwatch_log_delivery" "this" {
  count = var.enable_access_logs ? 1 : 0

  region                   = "us-east-1"
  delivery_source_name     = aws_cloudwatch_log_delivery_source.this[0].name
  delivery_destination_arn = aws_cloudwatch_log_delivery_destination.this[0].arn

  s3_delivery_configuration {
    suffix_path                 = "cloudfront/{yyyy}/{MM}/{dd}"
    enable_hive_compatible_path = false
  }
}
