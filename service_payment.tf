locals {
  payment_env = merge(local.common_env, {
    SERVICE                = "payment"
    PAYMENTS_TABLE         = aws_dynamodb_table.payments.name
    ORDERS_TABLE           = aws_dynamodb_table.orders.name
    PAYMENT_QUEUE_URL      = aws_sqs_queue.payment_requests.url
    ORDER_EVENTS_TOPIC_ARN = aws_sns_topic.order_events.arn
    GATEWAY_BASE_URL       = aws_apigatewayv2_api.gateway.api_endpoint
    GATEWAY_SECRET_NAME    = aws_secretsmanager_secret.gateway.name
  })

  payment_policy = [
    {
      sid = "PaymentsTable"
      actions = [
        "dynamodb:GetItem",
        "dynamodb:PutItem",
        "dynamodb:Query",
        "dynamodb:UpdateItem",
      ]
      resources = [
        aws_dynamodb_table.payments.arn,
        "${aws_dynamodb_table.payments.arn}/index/*",
      ]
    },
    {
      sid = "OrderStatusUpdate"
      actions = [
        "dynamodb:GetItem",
        "dynamodb:UpdateItem",
      ]
      resources = [aws_dynamodb_table.orders.arn]
    },
    {
      sid = "PaymentQueueConsume"
      actions = [
        "sqs:ReceiveMessage",
        "sqs:DeleteMessage",
        "sqs:GetQueueAttributes",
        "sqs:ChangeMessageVisibility",
      ]
      resources = [aws_sqs_queue.payment_requests.arn]
    },
    {
      sid       = "OrderEvents"
      actions   = ["sns:Publish"]
      resources = [aws_sns_topic.order_events.arn]
    },
    {
      sid       = "GatewaySecret"
      actions   = ["secretsmanager:GetSecretValue"]
      resources = [aws_secretsmanager_secret.gateway.arn]
    },
  ]

  gateway_env = merge(local.common_env, {
    SERVICE              = "payment"
    GATEWAY_LATENCY_MS   = tostring(var.gateway_latency_ms)
    GATEWAY_FAILURE_RATE = tostring(var.gateway_failure_rate)
    GATEWAY_SECRET_NAME  = aws_secretsmanager_secret.gateway.name
  })

  gateway_policy = [
    {
      sid       = "GatewaySecret"
      actions   = ["secretsmanager:GetSecretValue"]
      resources = [aws_secretsmanager_secret.gateway.arn]
    },
  ]
}

module "payment_process_payment" {
  source = "./modules/lambda_service"

  name              = "${local.service_names.payment}-process-payment"
  handler           = "handlers.process_payment.handler"
  artifact_path     = local.artifacts.payment
  env_vars          = local.payment_env
  memory_mb         = var.default_memory_mb
  timeout_s         = var.default_timeout_s
  policy_statements = local.payment_policy
  tags              = { Service = "payment" }
}

module "payment_get_payment" {
  source = "./modules/lambda_service"

  name              = "${local.service_names.payment}-get-payment"
  handler           = "handlers.get_payment.handler"
  artifact_path     = local.artifacts.payment
  env_vars          = local.payment_env
  memory_mb         = var.default_memory_mb
  timeout_s         = var.default_timeout_s
  policy_statements = local.payment_policy
  tags              = { Service = "payment" }
}

module "payment_gateway_charge" {
  source = "./modules/lambda_service"

  name              = "${local.service_names.gateway}-charge"
  handler           = "handlers.gateway_charge.handler"
  artifact_path     = local.artifacts.payment
  env_vars          = local.gateway_env
  memory_mb         = var.default_memory_mb
  timeout_s         = var.default_timeout_s
  policy_statements = local.gateway_policy
  tags              = { Service = "gateway" }
}

resource "aws_lambda_event_source_mapping" "payment_requests" {
  event_source_arn = aws_sqs_queue.payment_requests.arn
  function_name    = module.payment_process_payment.function_arn
  batch_size       = var.payment_esm_batch_size
  enabled          = var.payment_esm_enabled
}

resource "aws_apigatewayv2_api" "payment" {
  name          = local.service_names.payment
  protocol_type = "HTTP"

  tags = {
    Service = "payment"
  }
}

resource "aws_apigatewayv2_stage" "payment" {
  api_id      = aws_apigatewayv2_api.payment.id
  name        = "$default"
  auto_deploy = true
}

resource "aws_apigatewayv2_integration" "payment_get_payment" {
  api_id                 = aws_apigatewayv2_api.payment.id
  integration_type       = "AWS_PROXY"
  integration_uri        = module.payment_get_payment.invoke_arn
  integration_method     = "POST"
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "payment_get_payment" {
  api_id    = aws_apigatewayv2_api.payment.id
  route_key = "GET /payments/{payment_id}"
  target    = "integrations/${aws_apigatewayv2_integration.payment_get_payment.id}"
}

resource "aws_lambda_permission" "payment_get_payment" {
  statement_id  = "AllowInvokeFromApi"
  action        = "lambda:InvokeFunction"
  function_name = module.payment_get_payment.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.payment.execution_arn}/*/*"
}

resource "aws_apigatewayv2_api" "gateway" {
  name          = local.service_names.gateway
  protocol_type = "HTTP"

  tags = {
    Service = "gateway"
  }
}

resource "aws_apigatewayv2_stage" "gateway" {
  api_id      = aws_apigatewayv2_api.gateway.id
  name        = "$default"
  auto_deploy = true
}

resource "aws_apigatewayv2_integration" "gateway_charge" {
  api_id                 = aws_apigatewayv2_api.gateway.id
  integration_type       = "AWS_PROXY"
  integration_uri        = module.payment_gateway_charge.invoke_arn
  integration_method     = "POST"
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "gateway_charge" {
  api_id    = aws_apigatewayv2_api.gateway.id
  route_key = "POST /charge"
  target    = "integrations/${aws_apigatewayv2_integration.gateway_charge.id}"
}

resource "aws_lambda_permission" "gateway_charge" {
  statement_id  = "AllowInvokeFromApi"
  action        = "lambda:InvokeFunction"
  function_name = module.payment_gateway_charge.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.gateway.execution_arn}/*/*"
}
