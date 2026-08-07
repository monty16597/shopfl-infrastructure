resource "aws_secretsmanager_secret" "gateway" {
  name        = var.gateway_secret_name
  description = "Payment gateway API key used by shopfl-payment-${var.env}."

  # No recovery window, so a destroyed environment can be rebuilt under the same
  # name immediately instead of waiting out the default 30 day retention.
  recovery_window_in_days = 0

  tags = {
    Name    = var.gateway_secret_name
    Service = "payment"
  }
}

resource "aws_secretsmanager_secret_version" "gateway" {
  secret_id = aws_secretsmanager_secret.gateway.id

  secret_string = jsonencode({
    api_key = "shopfl-${var.env}-gateway-key"
  })
}
