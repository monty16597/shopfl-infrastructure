locals {
  catalog_env = merge(local.common_env, {
    SERVICE         = "catalog"
    PRODUCTS_TABLE  = aws_dynamodb_table.products.name
    PRODUCTS_BUCKET = aws_s3_bucket.products.bucket
  })

  catalog_policy = [
    {
      sid = "ProductsTable"
      actions = [
        "dynamodb:GetItem",
        "dynamodb:PutItem",
        "dynamodb:Query",
        "dynamodb:Scan",
        "dynamodb:UpdateItem",
      ]
      resources = [
        aws_dynamodb_table.products.arn,
        "${aws_dynamodb_table.products.arn}/index/*",
      ]
    },
    {
      sid       = "ProductMedia"
      actions   = ["s3:GetObject", "s3:PutObject"]
      resources = ["${aws_s3_bucket.products.arn}/*"]
    },
  ]
}

module "catalog_list_products" {
  source = "./modules/lambda_service"

  name              = "${local.service_names.catalog}-list-products"
  handler           = "handlers.list_products.handler"
  artifact_path     = local.artifacts.catalog
  env_vars          = local.catalog_env
  memory_mb         = var.catalog_memory_mb
  timeout_s         = var.default_timeout_s
  policy_statements = local.catalog_policy
  tags              = { Service = "catalog" }
}

module "catalog_get_product" {
  source = "./modules/lambda_service"

  name              = "${local.service_names.catalog}-get-product"
  handler           = "handlers.get_product.handler"
  artifact_path     = local.artifacts.catalog
  env_vars          = local.catalog_env
  memory_mb         = var.catalog_memory_mb
  timeout_s         = var.default_timeout_s
  policy_statements = local.catalog_policy
  tags              = { Service = "catalog" }
}

module "catalog_reserve" {
  source = "./modules/lambda_service"

  name              = "${local.service_names.catalog}-reserve"
  handler           = "handlers.reserve.handler"
  artifact_path     = local.artifacts.catalog
  env_vars          = local.catalog_env
  memory_mb         = var.catalog_memory_mb
  timeout_s         = var.default_timeout_s
  policy_statements = local.catalog_policy
  tags              = { Service = "catalog" }
}

module "catalog_release" {
  source = "./modules/lambda_service"

  name              = "${local.service_names.catalog}-release"
  handler           = "handlers.release.handler"
  artifact_path     = local.artifacts.catalog
  env_vars          = local.catalog_env
  memory_mb         = var.catalog_memory_mb
  timeout_s         = var.default_timeout_s
  policy_statements = local.catalog_policy
  tags              = { Service = "catalog" }
}

resource "aws_apigatewayv2_api" "catalog" {
  name          = local.service_names.catalog
  protocol_type = "HTTP"

  tags = {
    Service = "catalog"
  }
}

resource "aws_apigatewayv2_stage" "catalog" {
  api_id      = aws_apigatewayv2_api.catalog.id
  name        = "$default"
  auto_deploy = true
}

locals {
  catalog_routes = {
    "GET /products"                       = { invoke_arn = module.catalog_list_products.invoke_arn, function_name = module.catalog_list_products.function_name }
    "GET /products/{product_id}"          = { invoke_arn = module.catalog_get_product.invoke_arn, function_name = module.catalog_get_product.function_name }
    "POST /products/{product_id}/reserve" = { invoke_arn = module.catalog_reserve.invoke_arn, function_name = module.catalog_reserve.function_name }
    "POST /products/{product_id}/release" = { invoke_arn = module.catalog_release.invoke_arn, function_name = module.catalog_release.function_name }
  }
}

resource "aws_apigatewayv2_integration" "catalog" {
  for_each = local.catalog_routes

  api_id                 = aws_apigatewayv2_api.catalog.id
  integration_type       = "AWS_PROXY"
  integration_uri        = each.value.invoke_arn
  integration_method     = "POST"
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "catalog" {
  for_each = local.catalog_routes

  api_id    = aws_apigatewayv2_api.catalog.id
  route_key = each.key
  target    = "integrations/${aws_apigatewayv2_integration.catalog[each.key].id}"
}

resource "aws_lambda_permission" "catalog" {
  for_each = local.catalog_routes

  statement_id  = "AllowInvokeFromApi"
  action        = "lambda:InvokeFunction"
  function_name = each.value.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.catalog.execution_arn}/*/*"
}
