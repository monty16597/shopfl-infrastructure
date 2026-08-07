terraform {
  required_version = ">= 1.6"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

resource "aws_cloudwatch_metric_alarm" "this" {
  alarm_name        = var.name
  alarm_description = var.description

  namespace   = var.namespace
  metric_name = var.metric_name
  dimensions  = var.dimensions

  statistic          = var.extended_statistic == null ? var.statistic : null
  extended_statistic = var.extended_statistic

  period              = var.period
  evaluation_periods  = var.evaluation_periods
  datapoints_to_alarm = var.datapoints_to_alarm
  threshold           = var.threshold
  comparison_operator = var.comparison_operator
  treat_missing_data  = var.treat_missing_data

  actions_enabled = var.notifications_enabled && (
    length(var.notify_names) == 0 || contains(var.notify_names, var.name)
  )

  alarm_actions = var.alarm_actions
  ok_actions    = var.ok_actions

  tags = {
    Severity = var.severity
    Service  = var.service
    Env      = var.env
  }
}

output "alarm_name" {
  description = "Name of the created alarm."
  value       = aws_cloudwatch_metric_alarm.this.alarm_name
}

output "alarm_arn" {
  description = "ARN of the created alarm."
  value       = aws_cloudwatch_metric_alarm.this.arn
}
