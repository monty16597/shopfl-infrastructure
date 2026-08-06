resource "aws_secretsmanager_secret" "gateway" {
  name        = var.gateway_secret_name
  description = "Payment gateway API key used by shopfl-payment-${var.env}."

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
