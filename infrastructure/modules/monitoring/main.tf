data "aws_region" "current" {}

locals {
  region = data.aws_region.current.region

  alb_dimensions = {
    LoadBalancer = var.alb_arn_suffix
  }
  tg_dimensions = {
    LoadBalancer = var.alb_arn_suffix
    TargetGroup  = var.target_group_arn_suffix
  }
  ecs_dimensions = {
    ClusterName = var.ecs_cluster_name
    ServiceName = var.ecs_service_name
  }
  api_dimensions = {
    ApiId = var.api_id
    Stage = "$default"
  }
  aurora_dimensions = {
    DBClusterIdentifier = var.aurora_cluster_identifier
  }

  # Regional alarms, data-driven to keep them consistent.
  regional_alarms = {
    alb-5xx = {
      description = "The load balancer itself returned 5xx responses."
      namespace   = "AWS/ApplicationELB"
      metric      = "HTTPCode_ELB_5XX_Count"
      statistic   = "Sum"
      threshold   = 5
      operator    = "GreaterThanOrEqualToThreshold"
      dimensions  = local.alb_dimensions
    }
    target-5xx = {
      description = "Application tasks returned 5xx responses."
      namespace   = "AWS/ApplicationELB"
      metric      = "HTTPCode_Target_5XX_Count"
      statistic   = "Sum"
      threshold   = 5
      operator    = "GreaterThanOrEqualToThreshold"
      dimensions  = local.tg_dimensions
    }
    unhealthy-targets = {
      description = "At least one ECS task is failing ALB health checks."
      namespace   = "AWS/ApplicationELB"
      metric      = "UnHealthyHostCount"
      statistic   = "Maximum"
      threshold   = 1
      operator    = "GreaterThanOrEqualToThreshold"
      dimensions  = local.tg_dimensions
    }
    ecs-cpu-high = {
      description = "Service CPU is saturated even after scaling."
      namespace   = "AWS/ECS"
      metric      = "CPUUtilization"
      statistic   = "Average"
      threshold   = 85
      operator    = "GreaterThanOrEqualToThreshold"
      dimensions  = local.ecs_dimensions
    }
    ecs-memory-high = {
      description = "Service memory is close to the task limit."
      namespace   = "AWS/ECS"
      metric      = "MemoryUtilization"
      statistic   = "Average"
      threshold   = 85
      operator    = "GreaterThanOrEqualToThreshold"
      dimensions  = local.ecs_dimensions
    }
    api-5xx = {
      description = "API Gateway returned 5xx responses."
      namespace   = "AWS/ApiGateway"
      metric      = "5xx"
      statistic   = "Sum"
      threshold   = 5
      operator    = "GreaterThanOrEqualToThreshold"
      dimensions  = local.api_dimensions
    }
    aurora-acu-high = {
      description = "Aurora is running close to its maximum capacity."
      namespace   = "AWS/RDS"
      metric      = "ACUUtilization"
      statistic   = "Average"
      threshold   = 90
      operator    = "GreaterThanOrEqualToThreshold"
      dimensions  = local.aurora_dimensions
    }
    aurora-deadlocks = {
      description = "Deadlocks detected in Aurora."
      namespace   = "AWS/RDS"
      metric      = "Deadlocks"
      statistic   = "Sum"
      threshold   = 1
      operator    = "GreaterThanOrEqualToThreshold"
      dimensions  = local.aurora_dimensions
    }
  }
}

###############################################################################
# Notification topics. CloudWatch alarms can only notify an SNS topic in their
# own region, and CloudFront/WAF metrics only exist in us-east-1.
###############################################################################

resource "aws_sns_topic" "alarms" {
  name              = "${var.name}-alarms"
  kms_master_key_id = var.kms_key_arn
}

resource "aws_sns_topic" "alarms_global" {
  region            = "us-east-1"
  name              = "${var.name}-alarms-global"
  kms_master_key_id = var.global_kms_key_arn
}

resource "aws_sns_topic_subscription" "email" {
  count = var.alarm_email == null ? 0 : 1

  topic_arn = aws_sns_topic.alarms.arn
  protocol  = "email"
  endpoint  = var.alarm_email
}

resource "aws_sns_topic_subscription" "email_global" {
  count = var.alarm_email == null ? 0 : 1

  region    = "us-east-1"
  topic_arn = aws_sns_topic.alarms_global.arn
  protocol  = "email"
  endpoint  = var.alarm_email
}

###############################################################################
# Alarms
###############################################################################

resource "aws_cloudwatch_metric_alarm" "regional" {
  for_each = local.regional_alarms

  alarm_name          = "${var.name}-${each.key}"
  alarm_description   = each.value.description
  namespace           = each.value.namespace
  metric_name         = each.value.metric
  statistic           = each.value.statistic
  dimensions          = each.value.dimensions
  comparison_operator = each.value.operator
  threshold           = each.value.threshold
  period              = 60
  evaluation_periods  = 5
  datapoints_to_alarm = 3
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.alarms.arn]
  ok_actions          = [aws_sns_topic.alarms.arn]
}

resource "aws_cloudwatch_metric_alarm" "cloudfront_5xx_rate" {
  region = "us-east-1"

  alarm_name          = "${var.name}-cloudfront-5xx-rate"
  alarm_description   = "More than 5% of viewer requests end in 5xx at the edge."
  namespace           = "AWS/CloudFront"
  metric_name         = "5xxErrorRate"
  statistic           = "Average"
  dimensions          = { DistributionId = var.cloudfront_distribution_id, Region = "Global" }
  comparison_operator = "GreaterThanThreshold"
  threshold           = 5
  period              = 300
  evaluation_periods  = 2
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.alarms_global.arn]
  ok_actions          = [aws_sns_topic.alarms_global.arn]
}

resource "aws_cloudwatch_metric_alarm" "waf_blocked_spike" {
  region = "us-east-1"

  alarm_name          = "${var.name}-waf-blocked-spike"
  alarm_description   = "Unusual number of requests blocked by AWS WAF (possible attack)."
  namespace           = "AWS/WAFV2"
  metric_name         = "BlockedRequests"
  statistic           = "Sum"
  dimensions          = { WebACL = var.waf_web_acl_name, Rule = "ALL" }
  comparison_operator = "GreaterThanThreshold"
  threshold           = var.waf_blocked_requests_threshold
  period              = 300
  evaluation_periods  = 1
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.alarms_global.arn]
}

###############################################################################
# Dashboard
###############################################################################

resource "aws_cloudwatch_dashboard" "this" {
  dashboard_name = var.name

  dashboard_body = jsonencode({
    widgets = [
      {
        type = "metric", x = 0, y = 0, width = 12, height = 6
        properties = {
          title  = "Edge: CloudFront requests & 5xx rate"
          region = "us-east-1"
          stat   = "Sum"
          period = 300
          metrics = [
            ["AWS/CloudFront", "Requests", "DistributionId", var.cloudfront_distribution_id, "Region", "Global"],
            ["AWS/CloudFront", "5xxErrorRate", "DistributionId", var.cloudfront_distribution_id, "Region", "Global", { stat = "Average", yAxis = "right" }],
          ]
        }
      },
      {
        type = "metric", x = 12, y = 0, width = 12, height = 6
        properties = {
          title  = "Edge: WAF allowed vs blocked"
          region = "us-east-1"
          stat   = "Sum"
          period = 300
          metrics = [
            ["AWS/WAFV2", "AllowedRequests", "WebACL", var.waf_web_acl_name, "Rule", "ALL"],
            ["AWS/WAFV2", "BlockedRequests", "WebACL", var.waf_web_acl_name, "Rule", "ALL"],
          ]
        }
      },
      {
        type = "metric", x = 0, y = 6, width = 12, height = 6
        properties = {
          title  = "API Gateway: requests, 4xx, 5xx, latency p95"
          region = local.region
          period = 60
          metrics = [
            ["AWS/ApiGateway", "Count", "ApiId", var.api_id, "Stage", "$default", { stat = "Sum" }],
            ["AWS/ApiGateway", "4xx", "ApiId", var.api_id, "Stage", "$default", { stat = "Sum" }],
            ["AWS/ApiGateway", "5xx", "ApiId", var.api_id, "Stage", "$default", { stat = "Sum" }],
            ["AWS/ApiGateway", "Latency", "ApiId", var.api_id, "Stage", "$default", { stat = "p95", yAxis = "right" }],
          ]
        }
      },
      {
        type = "metric", x = 12, y = 6, width = 12, height = 6
        properties = {
          title  = "ALB: target response time p95 & 403 (blocked bypass attempts)"
          region = local.region
          period = 60
          metrics = [
            ["AWS/ApplicationELB", "TargetResponseTime", "LoadBalancer", var.alb_arn_suffix, { stat = "p95" }],
            ["AWS/ApplicationELB", "HTTPCode_ELB_4XX_Count", "LoadBalancer", var.alb_arn_suffix, { stat = "Sum", yAxis = "right" }],
          ]
        }
      },
      {
        type = "metric", x = 0, y = 12, width = 12, height = 6
        properties = {
          title  = "ECS: CPU / memory utilization"
          region = local.region
          stat   = "Average"
          period = 60
          metrics = [
            ["AWS/ECS", "CPUUtilization", "ClusterName", var.ecs_cluster_name, "ServiceName", var.ecs_service_name],
            ["AWS/ECS", "MemoryUtilization", "ClusterName", var.ecs_cluster_name, "ServiceName", var.ecs_service_name],
          ]
        }
      },
      {
        type = "metric", x = 12, y = 12, width = 12, height = 6
        properties = {
          title  = "Aurora Serverless v2: capacity (ACU) & connections"
          region = local.region
          period = 60
          metrics = [
            ["AWS/RDS", "ServerlessDatabaseCapacity", "DBClusterIdentifier", var.aurora_cluster_identifier, { stat = "Average" }],
            ["AWS/RDS", "DatabaseConnections", "DBClusterIdentifier", var.aurora_cluster_identifier, { stat = "Sum", yAxis = "right" }],
          ]
        }
      },
    ]
  })
}
