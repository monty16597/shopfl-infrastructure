resource "aws_dynamodb_table" "users" {
  name         = local.table_names.users
  billing_mode = var.table_billing_mode
  hash_key     = "user_id"

  attribute {
    name = "user_id"
    type = "S"
  }

  attribute {
    name = "email"
    type = "S"
  }

  global_secondary_index {
    name            = "email-index"
    hash_key        = "email"
    projection_type = "ALL"
  }

  tags = {
    Name    = local.table_names.users
    Service = "auth"
  }
}

resource "aws_dynamodb_table" "products" {
  name         = local.table_names.products
  billing_mode = var.table_billing_mode
  hash_key     = "product_id"

  attribute {
    name = "product_id"
    type = "S"
  }

  attribute {
    name = "category"
    type = "S"
  }

  global_secondary_index {
    name            = "category-index"
    hash_key        = "category"
    projection_type = "ALL"
  }

  tags = {
    Name    = local.table_names.products
    Service = "catalog"
  }
}

resource "aws_dynamodb_table" "carts" {
  name         = local.table_names.carts
  billing_mode = var.table_billing_mode
  hash_key     = "user_id"

  attribute {
    name = "user_id"
    type = "S"
  }

  tags = {
    Name    = local.table_names.carts
    Service = "cart"
  }
}

resource "aws_dynamodb_table" "orders" {
  name           = local.table_names.orders
  billing_mode   = var.orders_billing_mode
  hash_key       = "order_id"
  read_capacity  = var.orders_billing_mode == "PROVISIONED" ? var.orders_read_capacity : null
  write_capacity = var.orders_billing_mode == "PROVISIONED" ? var.orders_write_capacity : null

  attribute {
    name = "order_id"
    type = "S"
  }

  attribute {
    name = "user_id"
    type = "S"
  }

  attribute {
    name = "created_at"
    type = "S"
  }

  global_secondary_index {
    name            = "user-index"
    hash_key        = "user_id"
    range_key       = "created_at"
    projection_type = "ALL"
    read_capacity   = var.orders_billing_mode == "PROVISIONED" ? var.orders_read_capacity : null
    write_capacity  = var.orders_billing_mode == "PROVISIONED" ? var.orders_write_capacity : null
  }

  tags = {
    Name    = local.table_names.orders
    Service = "order"
  }
}

resource "aws_dynamodb_table" "payments" {
  name         = local.table_names.payments
  billing_mode = var.table_billing_mode
  hash_key     = "payment_id"

  attribute {
    name = "payment_id"
    type = "S"
  }

  attribute {
    name = "order_id"
    type = "S"
  }

  global_secondary_index {
    name            = "order-index"
    hash_key        = "order_id"
    projection_type = "ALL"
  }

  tags = {
    Name    = local.table_names.payments
    Service = "payment"
  }
}

resource "aws_dynamodb_table" "idempotency" {
  name         = local.table_names.idempotency
  billing_mode = var.table_billing_mode
  hash_key     = "idempotency_key"

  attribute {
    name = "idempotency_key"
    type = "S"
  }

  ttl {
    attribute_name = "expires_at"
    enabled        = true
  }

  tags = {
    Name    = local.table_names.idempotency
    Service = "order"
  }
}
