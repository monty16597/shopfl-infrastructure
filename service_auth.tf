locals {
  auth_env = merge(
    local.common_env,
    {
      SERVICE       = "auth"
      USERS_TABLE   = aws_dynamodb_table.users.name
      JWT_SECRET    = var.jwt_secret
      TOKEN_TTL_MIN = tostring(var.token_ttl_min)
    },
    var.auth_timezone == "UTC" ? {} : { TZ = var.auth_timezone },
  )

  auth_table_policy = [
    {
      sid = "UsersTable"
      actions = [
        "dynamodb:GetItem",
        "dynamodb:PutItem",
        "dynamodb:Query",
        "dynamodb:UpdateItem",
      ]
      resources = [
        aws_dynamodb_table.users.arn,
        "${aws_dynamodb_table.users.arn}/index/*",
      ]
    },
  ]
}

module "auth_signup" {
  source = "./modules/lambda_service"

  name              = "${local.service_names.auth}-signup"
  handler           = "handlers.signup.handler"
  artifact_path     = local.artifacts.auth
  env_vars          = local.auth_env
  memory_mb         = var.default_memory_mb
  timeout_s         = var.default_timeout_s
  policy_statements = local.auth_table_policy
  tags              = { Service = "auth" }
}

module "auth_login" {
  source = "./modules/lambda_service"

  name              = "${local.service_names.auth}-login"
  handler           = "handlers.login.handler"
  artifact_path     = local.artifacts.auth
  env_vars          = local.auth_env
  memory_mb         = var.default_memory_mb
  timeout_s         = var.default_timeout_s
  policy_statements = local.auth_table_policy
  tags              = { Service = "auth" }
}

module "auth_verify" {
  source = "./modules/lambda_service"

  name              = "${local.service_names.auth}-verify"
  handler           = "handlers.verify.handler"
  artifact_path     = local.artifacts.auth
  env_vars          = local.auth_env
  memory_mb         = var.default_memory_mb
  timeout_s         = var.default_timeout_s
  policy_statements = local.auth_table_policy
  tags              = { Service = "auth" }
}

resource "aws_apigatewayv2_api" "auth" {
  name          = local.service_names.auth
  protocol_type = "HTTP"

  tags = {
    Service = "auth"
  }
}

resource "aws_apigatewayv2_stage" "auth" {
  api_id      = aws_apigatewayv2_api.auth.id
  name        = "$default"
  auto_deploy = true
}

locals {
  auth_routes = {
    "POST /auth/signup" = { key = "signup", invoke_arn = module.auth_signup.invoke_arn, function_name = module.auth_signup.function_name }
    "POST /auth/login"  = { key = "login", invoke_arn = module.auth_login.invoke_arn, function_name = module.auth_login.function_name }
    "GET /auth/verify"  = { key = "verify", invoke_arn = module.auth_verify.invoke_arn, function_name = module.auth_verify.function_name }
  }
}

resource "aws_apigatewayv2_integration" "auth" {
  for_each = local.auth_routes

  api_id                 = aws_apigatewayv2_api.auth.id
  integration_type       = "AWS_PROXY"
  integration_uri        = each.value.invoke_arn
  integration_method     = "POST"
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "auth" {
  for_each = local.auth_routes

  api_id    = aws_apigatewayv2_api.auth.id
  route_key = each.key
  target    = "integrations/${aws_apigatewayv2_integration.auth[each.key].id}"
}

resource "aws_lambda_permission" "auth" {
  for_each = local.auth_routes

  statement_id  = "AllowInvokeFromApi"
  action        = "lambda:InvokeFunction"
  function_name = each.value.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.auth.execution_arn}/*/*"
}
