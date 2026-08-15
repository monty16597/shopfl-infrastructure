locals {
  # Representative function per service, used for the service level Lambda alarms.
  alarm_targets = {
    auth = {
      function  = module.auth_login.function_name
      log_group = module.auth_login.log_group_name
      api_id    = aws_apigatewayv2_api.auth.id
      api_name  = aws_apigatewayv2_api.auth.name
    }
    catalog = {
      function  = module.catalog_reserve.function_name
      log_group = module.catalog_reserve.log_group_name
      api_id    = aws_apigatewayv2_api.catalog.id
      api_name  = aws_apigatewayv2_api.catalog.name
    }
    cart = {
      function  = module.cart_put_item.function_name
      log_group = module.cart_put_item.log_group_name
      api_id    = aws_apigatewayv2_api.cart.id
      api_name  = aws_apigatewayv2_api.cart.name
    }
    order = {
      function  = module.order_create_order.function_name
      log_group = module.order_create_order.log_group_name
      api_id    = aws_apigatewayv2_api.order.id
      api_name  = aws_apigatewayv2_api.order.name
    }
    payment = {
      function  = module.payment_process_payment.function_name
      log_group = module.payment_process_payment.log_group_name
      api_id    = aws_apigatewayv2_api.payment.id
      api_name  = aws_apigatewayv2_api.payment.name
    }
    gateway = {
      function  = module.payment_gateway_charge.function_name
      log_group = module.payment_gateway_charge.log_group_name
      api_id    = aws_apigatewayv2_api.gateway.id
      api_name  = aws_apigatewayv2_api.gateway.name
    }
    notification = {
      function  = module.notification_consume_events.function_name
      log_group = module.notification_consume_events.log_group_name
      api_id    = aws_apigatewayv2_api.notification.id
      api_name  = aws_apigatewayv2_api.notification.name
    }
  }

  # Latency is judged on the customer-facing read path. For catalog that is the
  # product listing, not the reserve call order-service makes during checkout,
  # so duration alarms use their own target map.
  duration_targets = merge(local.alarm_targets, {
    catalog = {
      function  = module.catalog_list_products.function_name
      log_group = module.catalog_list_products.log_group_name
      api_id    = aws_apigatewayv2_api.catalog.id
      api_name  = aws_apigatewayv2_api.catalog.name
    }
  })

  alarm_actions = var.alarm_notifications_enabled && local.incident_topic_arn != null ? [local.incident_topic_arn] : []

  # Payment failures stop money moving, so a payment DLQ is revenue blocking.
  # A notification DLQ degrades the experience without blocking an order, so it
  # is alarmed at P1 in alarms_p1.tf.
  dlq_targets = {
    payment = {
      queue_name = aws_sqs_queue.payment_requests_dlq.name
      source     = aws_sqs_queue.payment_requests.name
    }
  }

  all_dlq_targets = {
    payment = {
      queue_name = aws_sqs_queue.payment_requests_dlq.name
      source     = aws_sqs_queue.payment_requests.name
    }
    notification = {
      queue_name = aws_sqs_queue.notifications_dlq.name
      source     = aws_sqs_queue.notifications.name
    }
  }

  main_queue_targets = {
    payment = {
      queue_name = aws_sqs_queue.payment_requests.name
    }
    notification = {
      queue_name = aws_sqs_queue.notifications.name
    }
  }

  table_alarm_targets = {
    auth    = aws_dynamodb_table.users.name
    catalog = aws_dynamodb_table.products.name
    cart    = aws_dynamodb_table.carts.name
    order   = aws_dynamodb_table.orders.name
    payment = aws_dynamodb_table.payments.name
  }
}

########################################
# Lambda errors
########################################

module "p0_lambda_errors" {
  source   = "./modules/alarms"
  for_each = local.alarm_targets

  name        = "${local.name_prefix}-${each.key}-${var.env}-p0-errors"
  severity    = "P0"
  service     = each.key
  env         = var.env
  description = "service=${each.key} function=${each.value.function} log_group=${each.value.log_group}"

  namespace   = "AWS/Lambda"
  metric_name = "Errors"
  dimensions  = { FunctionName = each.value.function }

  statistic          = "Sum"
  period             = var.alarm_period_s
  evaluation_periods = 1
  threshold          = var.lambda_error_threshold

  alarm_actions         = local.alarm_actions
  ok_actions            = local.alarm_actions
  notifications_enabled = var.alarm_notifications_enabled
  notify_names          = var.notify_alarm_names

}

########################################
# Lambda error rate
########################################

resource "aws_cloudwatch_metric_alarm" "p0_error_rate" {
  for_each = local.alarm_targets

  alarm_name        = "${local.name_prefix}-${each.key}-${var.env}-p0-error-rate"
  alarm_description = "service=${each.key} function=${each.value.function} log_group=${each.value.log_group}"

  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  threshold           = var.lambda_error_rate_threshold
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
    length(var.notify_alarm_names) == 0 || contains(var.notify_alarm_names, "${local.name_prefix}-${each.key}-${var.env}-p0-error-rate")
  )

  alarm_actions = local.alarm_actions
  ok_actions    = local.alarm_actions

  tags = {
    Severity = "P0"
    Service  = each.key
    Env      = var.env
  }
}

########################################
# API Gateway 5xx
########################################

module "p0_api_5xx" {
  source   = "./modules/alarms"
  for_each = local.alarm_targets

  name        = "${local.name_prefix}-${each.key}-${var.env}-p0-api-5xx"
  severity    = "P0"
  service     = each.key
  env         = var.env
  description = "service=${each.key} api=${each.value.api_name} log_group=${each.value.log_group}"

  namespace   = "AWS/ApiGateway"
  metric_name = "5xx"
  dimensions  = { ApiId = each.value.api_id }

  statistic          = "Sum"
  period             = var.alarm_period_s
  evaluation_periods = 1
  threshold          = var.api_5xx_threshold

  alarm_actions         = local.alarm_actions
  ok_actions            = local.alarm_actions
  notifications_enabled = var.alarm_notifications_enabled
  notify_names          = var.notify_alarm_names

}

########################################
# Dead letter queue depth
########################################

module "p0_dlq_depth" {
  source   = "./modules/alarms"
  for_each = local.dlq_targets

  name        = "${local.name_prefix}-${each.key}-${var.env}-p0-dlq-depth"
  severity    = "P0"
  service     = each.key
  env         = var.env
  description = "service=${each.key} queue=${each.value.queue_name} source_queue=${each.value.source}"

  namespace   = "AWS/SQS"
  metric_name = "ApproximateNumberOfMessagesVisible"
  dimensions  = { QueueName = each.value.queue_name }

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
# DynamoDB throttling
########################################

module "p0_table_throttles" {
  source   = "./modules/alarms"
  for_each = local.table_alarm_targets

  name        = "${local.name_prefix}-${each.key}-${var.env}-p0-table-throttles"
  severity    = "P0"
  service     = each.key
  env         = var.env
  description = "service=${each.key} table=${each.value}"

  # WriteThrottleEvents, NOT ThrottledRequests.
  #
  # DynamoDB publishes ThrottledRequests only against the paired dimension set
  # (TableName, Operation) — never against TableName on its own. An alarm keyed on TableName alone
  # therefore matches no metric stream at all and sits in OK forever. Confirmed on a live throttled
  # table: WriteThrottleEvents reported 56 in a single period while ThrottledRequests had no
  # datapoints and this alarm stayed OK. WriteThrottleEvents is published against TableName alone,
  # which is the dimension this alarm actually has.
  namespace   = "AWS/DynamoDB"
  metric_name = "WriteThrottleEvents"
  dimensions  = { TableName = each.value }

  statistic          = "Sum"
  period             = var.alarm_period_s
  evaluation_periods = 1
  threshold          = var.dynamodb_throttle_threshold

  alarm_actions         = local.alarm_actions
  ok_actions            = local.alarm_actions
  notifications_enabled = var.alarm_notifications_enabled
  notify_names          = var.notify_alarm_names

}

########################################
# Payment queue backlog
########################################

module "p0_payment_queue_age" {
  source = "./modules/alarms"

  name        = "${local.name_prefix}-payment-${var.env}-p0-queue-age"
  severity    = "P0"
  service     = "payment"
  env         = var.env
  description = "service=payment queue=${aws_sqs_queue.payment_requests.name} dlq=${aws_sqs_queue.payment_requests_dlq.name}"

  namespace   = "AWS/SQS"
  metric_name = "ApproximateAgeOfOldestMessage"
  dimensions  = { QueueName = aws_sqs_queue.payment_requests.name }

  statistic          = "Maximum"
  period             = var.alarm_period_s
  evaluation_periods = 1
  threshold          = var.payment_queue_age_p0_threshold_s

  alarm_actions         = local.alarm_actions
  ok_actions            = local.alarm_actions
  notifications_enabled = var.alarm_notifications_enabled
  notify_names          = var.notify_alarm_names

}

########################################
# Token rejection rate
########################################

# P0-APP-03 breaks the clock arithmetic in auth-service: login builds exp from datetime.now()
# while verify compares against datetime.utcnow(), so under any non-UTC TZ every token is rejected
# the instant it is issued. Nothing in the estate could see it. verify returns a clean 401 through
# _unauthorized() and logs at INFO, so AWS/Lambda Errors stays flat; the p0-error-rate and
# p0-errors alarms both watch shopfl-auth-dev-login, which succeeds - it mints the bad token
# perfectly - and p0-api-5xx watches 5xx, while a 401 is 4xx. A total auth outage was invisible on
# every existing signal. This filter is the missing one, and it matches the scenario's own stated
# signal: the 401 rate on /auth/verify.
resource "aws_cloudwatch_log_metric_filter" "auth_token_rejected" {
  name           = "${local.service_names.auth}-token-rejected"
  log_group_name = module.auth_verify.log_group_name
  pattern        = "{ $.event = \"verify_rejected\" }"

  metric_transformation {
    name          = "auth_token_rejected"
    namespace     = local.log_metric_namespace
    value         = "1"
    default_value = "0"
    unit          = "Count"
  }
}

module "p0_auth_token_rejection" {
  source = "./modules/alarms"

  name        = "${local.name_prefix}-auth-${var.env}-p0-token-rejection"
  severity    = "P0"
  service     = "auth"
  env         = var.env
  description = "service=auth log_group=${module.auth_verify.log_group_name} function=${module.auth_verify.function_name}"

  namespace   = local.log_metric_namespace
  metric_name = aws_cloudwatch_log_metric_filter.auth_token_rejected.metric_transformation[0].name

  statistic          = "Sum"
  period             = var.alarm_period_s
  evaluation_periods = 1
  threshold          = var.token_rejection_threshold
  treat_missing_data = "notBreaching"

  alarm_actions         = local.alarm_actions
  ok_actions            = local.alarm_actions
  notifications_enabled = var.alarm_notifications_enabled
  notify_names          = var.notify_alarm_names
}
