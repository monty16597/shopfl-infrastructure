########################################
# Lambda throttles
########################################

module "p1_lambda_throttles" {
  source   = "./modules/alarms"
  for_each = local.alarm_targets

  name        = "${local.name_prefix}-${each.key}-${var.env}-p1-throttles"
  severity    = "P1"
  service     = each.key
  env         = var.env
  description = "service=${each.key} function=${each.value.function} log_group=${each.value.log_group}"

  namespace   = "AWS/Lambda"
  metric_name = "Throttles"
  dimensions  = { FunctionName = each.value.function }

  statistic          = "Sum"
  period             = var.alarm_period_s
  evaluation_periods = 1
  threshold          = var.lambda_throttle_threshold

  alarm_actions         = local.alarm_actions
  ok_actions            = local.alarm_actions
  notifications_enabled = var.alarm_notifications_enabled
  notify_names          = var.notify_alarm_names

}

########################################
# Lambda duration p99
########################################

module "p1_duration_p99" {
  source   = "./modules/alarms"
  for_each = local.alarm_targets

  name        = "${local.name_prefix}-${each.key}-${var.env}-p1-duration-p99"
  severity    = "P1"
  service     = each.key
  env         = var.env
  description = "service=${each.key} function=${each.value.function} log_group=${each.value.log_group}"

  namespace   = "AWS/Lambda"
  metric_name = "Duration"
  dimensions  = { FunctionName = each.value.function }

  statistic          = null
  extended_statistic = "p99"
  period             = var.alarm_period_s
  evaluation_periods = 2
  threshold          = var.lambda_duration_p99_ms

  alarm_actions         = local.alarm_actions
  ok_actions            = local.alarm_actions
  notifications_enabled = var.alarm_notifications_enabled
  notify_names          = var.notify_alarm_names

}

########################################
# Queue backlog age
########################################

module "p1_queue_age" {
  source   = "./modules/alarms"
  for_each = local.main_queue_targets

  name        = "${local.name_prefix}-${each.key}-${var.env}-p1-queue-age"
  severity    = "P1"
  service     = each.key
  env         = var.env
  description = "service=${each.key} queue=${each.value.queue_name}"

  namespace   = "AWS/SQS"
  metric_name = "ApproximateAgeOfOldestMessage"
  dimensions  = { QueueName = each.value.queue_name }

  statistic          = "Maximum"
  period             = var.alarm_period_s
  evaluation_periods = 1
  threshold          = var.queue_age_threshold_s

  alarm_actions         = local.alarm_actions
  ok_actions            = local.alarm_actions
  notifications_enabled = var.alarm_notifications_enabled
  notify_names          = var.notify_alarm_names

}


########################################
# Notification dead letter queue depth
########################################

module "p1_notification_dlq_depth" {
  source = "./modules/alarms"

  name        = "${local.name_prefix}-notification-${var.env}-p1-dlq-depth"
  severity    = "P1"
  service     = "notification"
  env         = var.env
  description = "service=notification queue=${aws_sqs_queue.notifications_dlq.name} source_queue=${aws_sqs_queue.notifications.name}"

  namespace   = "AWS/SQS"
  metric_name = "ApproximateNumberOfMessagesVisible"
  dimensions  = { QueueName = aws_sqs_queue.notifications_dlq.name }

  statistic          = "Maximum"
  period             = var.alarm_period_s
  evaluation_periods = 1
  threshold          = var.dlq_depth_threshold

  alarm_actions         = local.alarm_actions
  ok_actions            = local.alarm_actions
  notifications_enabled = var.alarm_notifications_enabled
  notify_names          = var.notify_alarm_names

}

########################################
# Elevated error rate, below the paging threshold
########################################

resource "aws_cloudwatch_metric_alarm" "p1_error_rate" {
  for_each = local.alarm_targets

  alarm_name        = "${local.name_prefix}-${each.key}-${var.env}-p1-error-rate"
  alarm_description = "service=${each.key} function=${each.value.function} log_group=${each.value.log_group}"

  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  threshold           = var.lambda_error_rate_p1_threshold
  treat_missing_data  = "notBreaching"

  metric_query {
    id          = "errors"
    return_data = false

    metric {
      namespace   = "AWS/Lambda"
      metric_name = "Errors"
      dimensions  = { FunctionName = each.value.function }
      period      = var.alarm_period_s
      stat        = "Sum"
    }
  }

  metric_query {
    id          = "invocations"
    return_data = false

    metric {
      namespace   = "AWS/Lambda"
      metric_name = "Invocations"
      dimensions  = { FunctionName = each.value.function }
      period      = var.alarm_period_s
      stat        = "Sum"
    }
  }

  metric_query {
    id          = "rate"
    expression  = "100 * errors / IF(invocations > 0, invocations, 1)"
    label       = "error percentage"
    return_data = true
  }

  actions_enabled = var.alarm_notifications_enabled && (
    length(var.notify_alarm_names) == 0 || contains(var.notify_alarm_names, "${local.name_prefix}-${each.key}-${var.env}-p1-error-rate")
  )

  alarm_actions = local.alarm_actions
  ok_actions    = local.alarm_actions

  tags = {
    Severity = "P1"
    Service  = each.key
    Env      = var.env
  }
}
