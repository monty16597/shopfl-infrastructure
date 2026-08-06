locals {
  notification_env = merge(local.common_env, {
    SERVICE                = "notification"
    NOTIFICATION_QUEUE_URL = aws_sqs_queue.notifications.url
    ORDER_EVENTS_TOPIC_ARN = aws_sns_topic.order_events.arn
    SES_ENABLED            = var.ses_enabled ? "true" : "false"
    SES_SENDER             = var.ses_sender
    USERS_TABLE            = aws_dynamodb_table.users.name
  })

  notification_policy = [
    {
      sid = "NotificationQueueConsume"
      actions = [
        "sqs:ReceiveMessage",
        "sqs:DeleteMessage",
        "sqs:GetQueueAttributes",
        "sqs:ChangeMessageVisibility",
      ]
      resources = [aws_sqs_queue.notifications.arn]
    },
    {
      sid       = "RecipientLookup"
      actions   = ["dynamodb:GetItem"]
      resources = [aws_dynamodb_table.users.arn]
    },
    {
      sid       = "EmailDispatch"
      actions   = ["ses:SendEmail", "ses:SendRawEmail"]
      resources = ["*"]
    },
  ]
}

module "notification_consume_events" {
  source = "./modules/lambda_service"

  name              = "${local.service_names.notification}-consume-events"
  handler           = "handlers.consume_events.handler"
  artifact_path     = local.artifacts.notification
  env_vars          = local.notification_env
  memory_mb         = var.default_memory_mb
  timeout_s         = var.default_timeout_s
  policy_statements = local.notification_policy
  tags              = { Service = "notification" }
}

module "notification_health" {
  source = "./modules/lambda_service"

  name              = "${local.service_names.notification}-health"
  handler           = "handlers.health.handler"
  artifact_path     = local.artifacts.notification
  env_vars          = local.notification_env
  memory_mb         = var.default_memory_mb
  timeout_s         = var.default_timeout_s
  policy_statements = local.notification_policy
  tags              = { Service = "notification" }
}

resource "aws_lambda_event_source_mapping" "notifications" {
  event_source_arn = aws_sqs_queue.notifications.arn
  function_name    = module.notification_consume_events.function_arn
  batch_size       = var.notification_esm_batch_size
  enabled          = true
}

resource "aws_apigatewayv2_api" "notification" {
  name          = local.service_names.notification
  protocol_type = "HTTP"

  tags = {
    Service = "notification"
  }
}

resource "aws_apigatewayv2_stage" "notification" {
  api_id      = aws_apigatewayv2_api.notification.id
  name        = "$default"
  auto_deploy = true
}

resource "aws_apigatewayv2_integration" "notification_health" {
  api_id                 = aws_apigatewayv2_api.notification.id
  integration_type       = "AWS_PROXY"
  integration_uri        = module.notification_health.invoke_arn
  integration_method     = "POST"
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "notification_health" {
  api_id    = aws_apigatewayv2_api.notification.id
  route_key = "GET /health"
  target    = "integrations/${aws_apigatewayv2_integration.notification_health.id}"
}

resource "aws_lambda_permission" "notification_health" {
  statement_id  = "AllowInvokeFromApi"
  action        = "lambda:InvokeFunction"
  function_name = module.notification_health.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.notification.execution_arn}/*/*"
}
