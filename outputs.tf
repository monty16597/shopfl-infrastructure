output "auth_base_url" {
  description = "Base URL of the auth-service HTTP API."
  value       = aws_apigatewayv2_api.auth.api_endpoint
}

output "catalog_base_url" {
  description = "Base URL of the catalog-service HTTP API."
  value       = aws_apigatewayv2_api.catalog.api_endpoint
}

output "cart_base_url" {
  description = "Base URL of the cart-service HTTP API."
  value       = aws_apigatewayv2_api.cart.api_endpoint
}

output "order_base_url" {
  description = "Base URL of the order-service HTTP API."
  value       = aws_apigatewayv2_api.order.api_endpoint
}

output "payment_base_url" {
  description = "Base URL of the payment-service HTTP API."
  value       = aws_apigatewayv2_api.payment.api_endpoint
}

output "gateway_base_url" {
  description = "Base URL of the mock payment gateway HTTP API."
  value       = aws_apigatewayv2_api.gateway.api_endpoint
}

output "notification_base_url" {
  description = "Base URL of the notification-service HTTP API."
  value       = aws_apigatewayv2_api.notification.api_endpoint
}

output "payment_queue_url" {
  description = "URL of the payment request queue."
  value       = aws_sqs_queue.payment_requests.url
}

output "payment_dlq_url" {
  description = "URL of the payment request dead letter queue."
  value       = aws_sqs_queue.payment_requests_dlq.url
}

output "notification_queue_url" {
  description = "URL of the notification queue."
  value       = aws_sqs_queue.notifications.url
}

output "notification_dlq_url" {
  description = "URL of the notification dead letter queue."
  value       = aws_sqs_queue.notifications_dlq.url
}

output "order_events_topic_arn" {
  description = "ARN of the order events topic."
  value       = aws_sns_topic.order_events.arn
}

output "products_bucket_name" {
  description = "Name of the product media bucket."
  value       = aws_s3_bucket.products.bucket
}

output "gateway_secret_name" {
  description = "Secrets Manager secret name holding the payment gateway API key."
  value       = aws_secretsmanager_secret.gateway.name
}

output "incident_topic_arn" {
  description = "ARN of the SNS topic wired to every alarm action."
  value       = local.incident_topic_arn
}

output "table_names" {
  description = "DynamoDB table names by logical name."
  value = {
    users       = aws_dynamodb_table.users.name
    products    = aws_dynamodb_table.products.name
    carts       = aws_dynamodb_table.carts.name
    orders      = aws_dynamodb_table.orders.name
    payments    = aws_dynamodb_table.payments.name
    idempotency = aws_dynamodb_table.idempotency.name
  }
}

output "lambda_function_names" {
  description = "Lambda function names by service and handler."
  value = {
    auth_signup                 = module.auth_signup.function_name
    auth_login                  = module.auth_login.function_name
    auth_verify                 = module.auth_verify.function_name
    catalog_list_products       = module.catalog_list_products.function_name
    catalog_get_product         = module.catalog_get_product.function_name
    catalog_reserve             = module.catalog_reserve.function_name
    catalog_release             = module.catalog_release.function_name
    cart_get_cart               = module.cart_get_cart.function_name
    cart_put_item               = module.cart_put_item.function_name
    cart_delete_item            = module.cart_delete_item.function_name
    cart_delete_cart            = module.cart_delete_cart.function_name
    order_create_order          = module.order_create_order.function_name
    order_get_order             = module.order_get_order.function_name
    order_list_orders           = module.order_list_orders.function_name
    payment_process_payment     = module.payment_process_payment.function_name
    payment_get_payment         = module.payment_get_payment.function_name
    gateway_charge              = module.payment_gateway_charge.function_name
    notification_consume_events = module.notification_consume_events.function_name
    notification_health         = module.notification_health.function_name
  }
}

output "log_group_names" {
  description = "CloudWatch log group names by service and handler."
  value = {
    auth_signup                 = module.auth_signup.log_group_name
    auth_login                  = module.auth_login.log_group_name
    auth_verify                 = module.auth_verify.log_group_name
    catalog_list_products       = module.catalog_list_products.log_group_name
    catalog_get_product         = module.catalog_get_product.log_group_name
    catalog_reserve             = module.catalog_reserve.log_group_name
    catalog_release             = module.catalog_release.log_group_name
    cart_get_cart               = module.cart_get_cart.log_group_name
    cart_put_item               = module.cart_put_item.log_group_name
    cart_delete_item            = module.cart_delete_item.log_group_name
    cart_delete_cart            = module.cart_delete_cart.log_group_name
    order_create_order          = module.order_create_order.log_group_name
    order_get_order             = module.order_get_order.log_group_name
    order_list_orders           = module.order_list_orders.log_group_name
    payment_process_payment     = module.payment_process_payment.log_group_name
    payment_get_payment         = module.payment_get_payment.log_group_name
    gateway_charge              = module.payment_gateway_charge.log_group_name
    notification_consume_events = module.notification_consume_events.log_group_name
    notification_health         = module.notification_health.log_group_name
  }
}
