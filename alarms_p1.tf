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

  alarm_actions = local.alarm_actions
  ok_actions    = local.alarm_actions
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

  alarm_actions = local.alarm_actions
  ok_actions    = local.alarm_actions
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

  alarm_actions = local.alarm_actions
  ok_actions    = local.alarm_actions
}

########################################
# Scheduled rule failures
########################################

module "p1_rule_failed_invocations" {
  source = "./modules/alarms"

  name        = "${local.name_prefix}-cart-${var.env}-p1-rule-failed-invocations"
  severity    = "P1"
  service     = "cart"
  env         = var.env
  description = "service=cart rule=${local.cart_sweeper_rule_name} table=${local.table_names.carts}"

  namespace   = "AWS/Events"
  metric_name = "FailedInvocations"
  dimensions  = { RuleName = local.cart_sweeper_rule_name }

  statistic          = "Sum"
  period             = var.alarm_period_s
  evaluation_periods = 1
  threshold          = var.eventbridge_failure_threshold

  alarm_actions = local.alarm_actions
  ok_actions    = local.alarm_actions
}
