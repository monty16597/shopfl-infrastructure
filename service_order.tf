locals {
  order_env = merge(local.common_env, {
    SERVICE                = "order"
    ORDERS_TABLE           = aws_dynamodb_table.orders.name
    IDEMPOTENCY_TABLE      = aws_dynamodb_table.idempotency.name
    PRODUCTS_TABLE         = aws_dynamodb_table.products.name
    CART_BASE_URL          = aws_apigatewayv2_api.cart.api_endpoint
    CATALOG_BASE_URL       = aws_apigatewayv2_api.catalog.api_endpoint
    PAYMENT_QUEUE_URL      = aws_sqs_queue.payment_requests.url
    ORDER_EVENTS_TOPIC_ARN = aws_sns_topic.order_events.arn
    JWT_SECRET             = var.jwt_secret
  })

  order_table_actions = concat(
    [
      "dynamodb:GetItem",
      "dynamodb:Query",
      "dynamodb:UpdateItem",
    ],
    var.order_role_allow_put_item ? ["dynamodb:PutItem"] : []
  )

  order_policy = [
    {
      sid     = "OrdersTable"
      actions = local.order_table_actions
      resources = [
        aws_dynamodb_table.orders.arn,
        "${aws_dynamodb_table.orders.arn}/index/*",
      ]
    },
    {
      sid = "IdempotencyTable"
      actions = [
        "dynamodb:GetItem",
        "dynamodb:PutItem",
        "dynamodb:UpdateItem",
      ]
      resources = [aws_dynamodb_table.idempotency.arn]
    },
    {
      sid = "ProductLookup"
      actions = [
        "dynamodb:GetItem",
        "dynamodb:BatchGetItem",
      ]
      resources = [aws_dynamodb_table.products.arn]
    },
    {
      sid       = "PaymentQueue"
      actions   = ["sqs:SendMessage", "sqs:GetQueueAttributes"]
      resources = [aws_sqs_queue.payment_requests.arn]
    },
    {
      sid       = "OrderEvents"
      actions   = ["sns:Publish"]
      resources = [aws_sns_topic.order_events.arn]
    },
  ]
}

module "order_create_order" {
  source = "./modules/lambda_service"

  name              = "${local.service_names.order}-create-order"
  handler           = "handlers.create_order.handler"
  artifact_path     = local.artifacts.order
  env_vars          = local.order_env
  memory_mb         = var.default_memory_mb
  timeout_s         = var.order_timeout_s
  policy_statements = local.order_policy
  tags              = { Service = "order" }
}

module "order_get_order" {
  source = "./modules/lambda_service"

  name              = "${local.service_names.order}-get-order"
  handler           = "handlers.get_order.handler"
  artifact_path     = local.artifacts.order
  env_vars          = local.order_env
  memory_mb         = var.default_memory_mb
  timeout_s         = var.order_timeout_s
  policy_statements = local.order_policy
  tags              = { Service = "order" }
}

module "order_list_orders" {
  source = "./modules/lambda_service"

  name              = "${local.service_names.order}-list-orders"
  handler           = "handlers.list_orders.handler"
  artifact_path     = local.artifacts.order
  env_vars          = local.order_env
  memory_mb         = var.default_memory_mb
  timeout_s         = var.order_timeout_s
  policy_statements = local.order_policy
  tags              = { Service = "order" }
}

resource "aws_apigatewayv2_api" "order" {
  name          = local.service_names.order
  protocol_type = "HTTP"

  tags = {
    Service = "order"
  }
}

resource "aws_apigatewayv2_stage" "order" {
  api_id      = aws_apigatewayv2_api.order.id
  name        = "$default"
  auto_deploy = true
}

locals {
  order_routes = {
    "POST /orders"           = { invoke_arn = module.order_create_order.invoke_arn, function_name = module.order_create_order.function_name }
    "GET /orders/{order_id}" = { invoke_arn = module.order_get_order.invoke_arn, function_name = module.order_get_order.function_name }
    "GET /orders"            = { invoke_arn = module.order_list_orders.invoke_arn, function_name = module.order_list_orders.function_name }
  }
}

resource "aws_apigatewayv2_integration" "order" {
  for_each = local.order_routes

  api_id                 = aws_apigatewayv2_api.order.id
  integration_type       = "AWS_PROXY"
  integration_uri        = each.value.invoke_arn
  integration_method     = "POST"
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "order" {
  for_each = local.order_routes

  api_id    = aws_apigatewayv2_api.order.id
  route_key = each.key
  target    = "integrations/${aws_apigatewayv2_integration.order[each.key].id}"
}

resource "aws_lambda_permission" "order" {
  for_each = local.order_routes

  statement_id  = "AllowInvokeFromApi"
  action        = "lambda:InvokeFunction"
  function_name = each.value.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.order.execution_arn}/*/*"
}
