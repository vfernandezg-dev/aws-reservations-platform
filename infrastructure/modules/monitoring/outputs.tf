output "alarm_topic_arn" {
  description = "SNS topic receiving regional alarms."
  value       = aws_sns_topic.alarms.arn
}

output "global_alarm_topic_arn" {
  description = "SNS topic (us-east-1) receiving CloudFront and WAF alarms."
  value       = aws_sns_topic.alarms_global.arn
}

output "dashboard_name" {
  description = "Name of the CloudWatch dashboard."
  value       = aws_cloudwatch_dashboard.this.dashboard_name
}
