########################################
# Warning log volume
########################################

resource "aws_cloudwatch_log_metric_filter" "order_warn_events" {
  name           = "${local.service_names.order}-warn-events"
  log_group_name = module.order_create_order.log_group_name
  pattern        = "{ $.level = \"WARNING\" }"

  metric_transformation {
    name          = "order_warn_events"
    namespace     = local.log_metric_namespace
    value         = "1"
    default_value = "0"
    unit          = "Count"
  }
}

module "p2_warn_rate" {
  source = "./modules/alarms"

  name        = "${local.name_prefix}-order-${var.env}-p2-warn-rate"
  severity    = "P2"
  service     = "order"
  env         = var.env
  description = "service=order log_group=${module.order_create_order.log_group_name} table=${local.table_names.orders}"

  namespace   = local.log_metric_namespace
  metric_name = aws_cloudwatch_log_metric_filter.order_warn_events.metric_transformation[0].name

  statistic          = "Sum"
  period             = var.alarm_period_s
  evaluation_periods = 1
  threshold          = var.warn_rate_threshold

  alarm_actions = local.alarm_actions
  ok_actions    = local.alarm_actions
}

########################################
# Email address pattern in log payloads
########################################

resource "aws_cloudwatch_log_metric_filter" "catalog_email_pattern" {
  name           = "${local.service_names.catalog}-email-pattern"
  log_group_name = module.catalog_reserve.log_group_name
  pattern        = "{ $.body = \"*@*.*\" }"

  metric_transformation {
    name          = "catalog_email_pattern_matches"
    namespace     = local.log_metric_namespace
    value         = "1"
    default_value = "0"
    unit          = "Count"
  }
}

module "p2_email_pattern" {
  source = "./modules/alarms"

  name        = "${local.name_prefix}-catalog-${var.env}-p2-email-pattern"
  severity    = "P2"
  service     = "catalog"
  env         = var.env
  description = "service=catalog log_group=${module.catalog_reserve.log_group_name} table=${local.table_names.products}"

  namespace   = local.log_metric_namespace
  metric_name = aws_cloudwatch_log_metric_filter.catalog_email_pattern.metric_transformation[0].name

  statistic          = "Sum"
  period             = var.alarm_period_s
  evaluation_periods = 1
  threshold          = var.email_pattern_threshold

  alarm_actions = local.alarm_actions
  ok_actions    = local.alarm_actions
}

########################################
# Published order events versus sent notifications
########################################

resource "aws_cloudwatch_metric_alarm" "p2_event_delivery_delta" {
  alarm_name        = "${local.name_prefix}-notification-${var.env}-p2-event-delivery-delta"
  alarm_description = "service=notification log_group=${module.notification_consume_events.log_group_name} queue=${aws_sqs_queue.notifications.name} topic=${aws_sns_topic.order_events.name}"

  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  threshold           = var.event_delivery_delta_threshold
  treat_missing_data  = "notBreaching"

  metric_query {
    id          = "published"
    return_data = false

    metric {
      namespace   = local.metric_namespace
      metric_name = "order_events_published"
      dimensions  = { service = "order" }
      period      = var.alarm_period_s
      stat        = "Sum"
    }
  }

  metric_query {
    id          = "sent"
    return_data = false

    metric {
      namespace   = local.metric_namespace
      metric_name = "notifications_sent"
      dimensions  = { service = "notification" }
      period      = var.alarm_period_s
      stat        = "Sum"
    }
  }

  metric_query {
    id          = "delta"
    expression  = "published - sent"
    label       = "undelivered order events"
    return_data = true
  }

  alarm_actions = local.alarm_actions
  ok_actions    = local.alarm_actions

  tags = {
    Severity = "P2"
    Service  = "notification"
    Env      = var.env
  }
}

########################################
# Scheduled rule failures
########################################

module "p2_sweeper_failures" {
  source = "./modules/alarms"

  name        = "${local.name_prefix}-cart-${var.env}-p2-sweeper-failures"
  severity    = "P2"
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

########################################
# Dead letter messages approaching retention expiry
########################################

module "p2_dlq_age" {
  source   = "./modules/alarms"
  for_each = local.all_dlq_targets

  name        = "${local.name_prefix}-${each.key}-${var.env}-p2-dlq-age"
  severity    = "P2"
  service     = each.key
  env         = var.env
  description = "service=${each.key} queue=${each.value.queue_name} source_queue=${each.value.source}"

  namespace   = "AWS/SQS"
  metric_name = "ApproximateAgeOfOldestMessage"
  dimensions  = { QueueName = each.value.queue_name }

  statistic          = "Maximum"
  period             = var.alarm_period_s
  evaluation_periods = 1
  threshold          = var.dlq_age_threshold_s

  alarm_actions = local.alarm_actions
  ok_actions    = local.alarm_actions
}

########################################
# Platform configuration hygiene
########################################

module "p2_log_retention" {
  source = "./modules/alarms"

  name        = "${local.name_prefix}-infra-${var.env}-p2-log-retention"
  severity    = "P2"
  service     = "infra"
  env         = var.env
  description = "service=infra check_function=${aws_lambda_function.config_check.function_name} log_group=${aws_cloudwatch_log_group.config_check.name}"

  namespace   = "ShopFL/Config"
  metric_name = "log_groups_without_retention"
  dimensions  = { env = var.env }

  statistic          = "Maximum"
  period             = var.config_check_alarm_period_s
  evaluation_periods = 1
  threshold          = var.log_retention_threshold
  # Strictly greater than: these thresholds are "how many findings are tolerated",
  # so a >= comparison against 0 would alarm even when there is nothing to report.
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "missing"

  alarm_actions = local.alarm_actions
  ok_actions    = local.alarm_actions
}

module "p2_bucket_config" {
  source = "./modules/alarms"

  name        = "${local.name_prefix}-infra-${var.env}-p2-bucket-config"
  severity    = "P2"
  service     = "infra"
  env         = var.env
  description = "service=infra bucket=${aws_s3_bucket.products.bucket} check_function=${aws_lambda_function.config_check.function_name}"

  namespace   = "ShopFL/Config"
  metric_name = "bucket_config_findings"
  dimensions  = { env = var.env }

  statistic          = "Maximum"
  period             = var.config_check_alarm_period_s
  evaluation_periods = 1
  threshold          = var.bucket_config_threshold
  # Strictly greater than: these thresholds are "how many findings are tolerated",
  # so a >= comparison against 0 would alarm even when there is nothing to report.
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "missing"

  alarm_actions = local.alarm_actions
  ok_actions    = local.alarm_actions
}

module "p2_cart_item_count" {
  source = "./modules/alarms"

  name        = "${local.name_prefix}-cart-${var.env}-p2-item-count"
  severity    = "P2"
  service     = "cart"
  env         = var.env
  description = "service=cart table=${local.table_names.carts} check_function=${aws_lambda_function.config_check.function_name}"

  namespace   = "ShopFL/Config"
  metric_name = "carts_item_count"
  dimensions  = { env = var.env }

  statistic          = "Maximum"
  period             = var.config_check_alarm_period_s
  evaluation_periods = 1
  threshold          = var.carts_item_count_threshold
  treat_missing_data = "missing"

  alarm_actions = local.alarm_actions
  ok_actions    = local.alarm_actions
}
