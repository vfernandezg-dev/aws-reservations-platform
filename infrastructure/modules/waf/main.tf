# Web ACLs with CLOUDFRONT scope must live in us-east-1. AWS provider v6
# supports a per-resource `region` argument, so no provider alias is needed.
locals {
  region = "us-east-1"

  managed_rule_groups = [
    {
      name        = "AWSManagedRulesAmazonIpReputationList"
      priority    = 10
      count_rules = []
    },
    {
      name     = "AWSManagedRulesCommonRuleSet"
      priority = 20
      # Bodies over 8 KB are legitimate for some API calls: count, don't block.
      count_rules = ["SizeRestrictions_BODY"]
    },
    {
      name        = "AWSManagedRulesKnownBadInputsRuleSet" # includes Log4j / Log4Shell
      priority    = 30
      count_rules = []
    },
    {
      name        = "AWSManagedRulesSQLiRuleSet"
      priority    = 40
      count_rules = []
    },
  ]
}

data "aws_caller_identity" "current" {}

resource "aws_wafv2_web_acl" "this" {
  region      = local.region
  name        = var.name
  description = "Edge protection for the ${var.name} CloudFront distribution"
  scope       = "CLOUDFRONT"

  default_action {
    allow {}
  }

  dynamic "rule" {
    for_each = length(var.blocked_country_codes) > 0 ? [1] : []

    content {
      name     = "GeoBlock"
      priority = 0

      action {
        block {}
      }

      statement {
        geo_match_statement {
          country_codes = var.blocked_country_codes
        }
      }

      visibility_config {
        cloudwatch_metrics_enabled = true
        metric_name                = "GeoBlock"
        sampled_requests_enabled   = true
      }
    }
  }

  dynamic "rule" {
    for_each = local.managed_rule_groups

    content {
      name     = rule.value.name
      priority = rule.value.priority

      override_action {
        none {}
      }

      statement {
        managed_rule_group_statement {
          name        = rule.value.name
          vendor_name = "AWS"

          dynamic "rule_action_override" {
            for_each = rule.value.count_rules

            content {
              name = rule_action_override.value

              action_to_use {
                count {}
              }
            }
          }
        }
      }

      visibility_config {
        cloudwatch_metrics_enabled = true
        metric_name                = rule.value.name
        sampled_requests_enabled   = true
      }
    }
  }

  rule {
    name     = "RateLimitPerIp"
    priority = 100

    action {
      block {}
    }

    statement {
      rate_based_statement {
        limit                 = var.rate_limit_per_5_minutes
        aggregate_key_type    = "IP"
        evaluation_window_sec = 300
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "RateLimitPerIp"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = replace(var.name, "-", "")
    sampled_requests_enabled   = true
  }

  tags = {
    Name = var.name
  }
}

###############################################################################
# Logging (log group name MUST start with "aws-waf-logs-")
###############################################################################

resource "aws_cloudwatch_log_group" "this" {
  count = var.enable_logging ? 1 : 0

  region            = local.region
  name              = "aws-waf-logs-${var.name}"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.kms_key_arn
}

data "aws_iam_policy_document" "logs" {
  count = var.enable_logging ? 1 : 0

  statement {
    sid       = "AllowWafLogDelivery"
    actions   = ["logs:CreateLogStream", "logs:PutLogEvents"]
    resources = ["${aws_cloudwatch_log_group.this[0].arn}:*"]

    principals {
      type        = "Service"
      identifiers = ["delivery.logs.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }

    condition {
      test     = "ArnLike"
      variable = "aws:SourceArn"
      values   = ["arn:aws:logs:${local.region}:${data.aws_caller_identity.current.account_id}:*"]
    }
  }
}

resource "aws_cloudwatch_log_resource_policy" "this" {
  count = var.enable_logging ? 1 : 0

  region          = local.region
  policy_name     = "${var.name}-waf-logs"
  policy_document = data.aws_iam_policy_document.logs[0].json
}

resource "aws_wafv2_web_acl_logging_configuration" "this" {
  count = var.enable_logging ? 1 : 0

  region                  = local.region
  resource_arn            = aws_wafv2_web_acl.this.arn
  log_destination_configs = [aws_cloudwatch_log_group.this[0].arn]

  redacted_fields {
    single_header {
      name = "authorization"
    }
  }

  redacted_fields {
    single_header {
      name = "cookie"
    }
  }

  depends_on = [aws_cloudwatch_log_resource_policy.this]
}
