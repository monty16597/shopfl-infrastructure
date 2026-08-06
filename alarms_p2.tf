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
