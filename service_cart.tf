locals {
  cart_env = merge(local.common_env, {
    SERVICE           = "cart"
    CARTS_TABLE       = aws_dynamodb_table.carts.name
    CATALOG_BASE_URL  = aws_apigatewayv2_api.catalog.api_endpoint
    CART_TTL_DAYS     = "30"
    PRODUCTS_TABLE    = aws_dynamodb_table.products.name
    CATALOG_TIMEOUT_S = "5"
  })

  cart_policy = [
    {
      sid = "CartsTable"
      actions = [
        "dynamodb:GetItem",
        "dynamodb:PutItem",
        "dynamodb:UpdateItem",
        "dynamodb:DeleteItem",
        "dynamodb:Query",
        "dynamodb:Scan",
      ]
      resources = [aws_dynamodb_table.carts.arn]
    },
  ]
}

module "cart_get_cart" {
  source = "./modules/lambda_service"

  name                 = "${local.service_names.cart}-get-cart"
  handler              = "handlers.get_cart.handler"
  artifact_path        = local.artifacts.cart
  env_vars             = local.cart_env
  memory_mb            = var.default_memory_mb
  timeout_s            = var.default_timeout_s
  reserved_concurrency = var.cart_reserved_concurrency
  policy_statements    = local.cart_policy
  tags                 = { Service = "cart" }
}

module "cart_put_item" {
  source = "./modules/lambda_service"

  name                 = "${local.service_names.cart}-put-item"
  handler              = "handlers.put_item.handler"
  artifact_path        = local.artifacts.cart
  env_vars             = local.cart_env
  memory_mb            = var.default_memory_mb
  timeout_s            = var.default_timeout_s
  reserved_concurrency = var.cart_reserved_concurrency
  policy_statements    = local.cart_policy
  tags                 = { Service = "cart" }
}

module "cart_delete_item" {
  source = "./modules/lambda_service"

  name                 = "${local.service_names.cart}-delete-item"
  handler              = "handlers.delete_item.handler"
  artifact_path        = local.artifacts.cart
  env_vars             = local.cart_env
  memory_mb            = var.default_memory_mb
  timeout_s            = var.default_timeout_s
  reserved_concurrency = var.cart_reserved_concurrency
  policy_statements    = local.cart_policy
  tags                 = { Service = "cart" }
}

module "cart_delete_cart" {
  source = "./modules/lambda_service"

  name                 = "${local.service_names.cart}-delete-cart"
  handler              = "handlers.delete_cart.handler"
  artifact_path        = local.artifacts.cart
  env_vars             = local.cart_env
  memory_mb            = var.default_memory_mb
  timeout_s            = var.default_timeout_s
  reserved_concurrency = var.cart_reserved_concurrency
  policy_statements    = local.cart_policy
  tags                 = { Service = "cart" }
}

resource "aws_apigatewayv2_api" "cart" {
  name          = local.service_names.cart
  protocol_type = "HTTP"

  tags = {
    Service = "cart"
  }
}

resource "aws_apigatewayv2_stage" "cart" {
  api_id      = aws_apigatewayv2_api.cart.id
  name        = "$default"
  auto_deploy = true
}

locals {
  cart_routes = {
    "GET /carts/{user_id}"                       = { invoke_arn = module.cart_get_cart.invoke_arn, function_name = module.cart_get_cart.function_name }
    "PUT /carts/{user_id}/items"                 = { invoke_arn = module.cart_put_item.invoke_arn, function_name = module.cart_put_item.function_name }
    "DELETE /carts/{user_id}/items/{product_id}" = { invoke_arn = module.cart_delete_item.invoke_arn, function_name = module.cart_delete_item.function_name }
    "DELETE /carts/{user_id}"                    = { invoke_arn = module.cart_delete_cart.invoke_arn, function_name = module.cart_delete_cart.function_name }
  }
}

resource "aws_apigatewayv2_integration" "cart" {
  for_each = local.cart_routes

  api_id                 = aws_apigatewayv2_api.cart.id
  integration_type       = "AWS_PROXY"
  integration_uri        = each.value.invoke_arn
  integration_method     = "POST"
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "cart" {
  for_each = local.cart_routes

  api_id    = aws_apigatewayv2_api.cart.id
  route_key = each.key
  target    = "integrations/${aws_apigatewayv2_integration.cart[each.key].id}"
}

resource "aws_lambda_permission" "cart" {
  for_each = local.cart_routes

  statement_id  = "AllowInvokeFromApi"
  action        = "lambda:InvokeFunction"
  function_name = each.value.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.cart.execution_arn}/*/*"
}
