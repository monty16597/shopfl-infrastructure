locals {
  incident_topic_arn = try(
    coalesce(var.incident_topic_arn, data.aws_sns_topic.incidents[0].arn),
    null,
  )

  account_id = data.aws_caller_identity.current.account_id
  region     = data.aws_region.current.name

  name_prefix = "shopfl"
  suffix      = var.env

  # shopfl-<service>-<env>
  service_names = {
    auth         = "${local.name_prefix}-auth-${local.suffix}"
    catalog      = "${local.name_prefix}-catalog-${local.suffix}"
    cart         = "${local.name_prefix}-cart-${local.suffix}"
    order        = "${local.name_prefix}-order-${local.suffix}"
    payment      = "${local.name_prefix}-payment-${local.suffix}"
    gateway      = "${local.name_prefix}-gateway-${local.suffix}"
    notification = "${local.name_prefix}-notification-${local.suffix}"
  }

  artifacts = {
    auth         = "${var.artifact_root}/shopfl-auth-service/dist/shopfl-auth.zip"
    catalog      = "${var.artifact_root}/shopfl-catalog-service/dist/shopfl-catalog.zip"
    cart         = "${var.artifact_root}/shopfl-cart-service/dist/shopfl-cart.zip"
    order        = "${var.artifact_root}/shopfl-order-service/dist/shopfl-order.zip"
    payment      = "${var.artifact_root}/shopfl-payment-service/dist/shopfl-payment.zip"
    notification = "${var.artifact_root}/shopfl-notification-service/dist/shopfl-notification.zip"
  }

  table_names = {
    users       = "${local.name_prefix}-users-${local.suffix}"
    products    = "${local.name_prefix}-products-${local.suffix}"
    carts       = "${local.name_prefix}-carts-${local.suffix}"
    orders      = "${local.name_prefix}-orders-${local.suffix}"
    payments    = "${local.name_prefix}-payments-${local.suffix}"
    idempotency = "${local.name_prefix}-idempotency-${local.suffix}"
  }

  queue_names = {
    payment_requests     = "${local.name_prefix}-payment-requests-${local.suffix}"
    payment_requests_dlq = "${local.name_prefix}-payment-requests-${local.suffix}-dlq"
    notifications        = "${local.name_prefix}-notifications-${local.suffix}"
    notifications_dlq    = "${local.name_prefix}-notifications-${local.suffix}-dlq"
  }

  order_events_topic_name = "${local.name_prefix}-order-events-${local.suffix}"
  # S3 names are globally unique, so the name carries a random suffix held in
  # state rather than the account id.
  products_bucket_name   = "${local.name_prefix}-products-${local.suffix}-${random_id.products_bucket.hex}"
  cart_sweeper_rule_name = "${local.name_prefix}-cart-sweeper-${local.suffix}"

  metric_namespace     = "ShopFL"
  log_metric_namespace = "ShopFL/Logs"

  common_env = {
    ENV       = var.env
    LOG_LEVEL = var.log_level
  }
}
