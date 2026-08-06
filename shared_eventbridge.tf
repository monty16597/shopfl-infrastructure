resource "aws_cloudwatch_event_rule" "cart_sweeper" {
  count = var.cart_sweeper_enabled ? 1 : 0

  name                = local.cart_sweeper_rule_name
  description         = "Scheduled sweep of expired carts in ${local.table_names.carts}."
  schedule_expression = var.cart_sweeper_schedule
  state               = "ENABLED"

  tags = {
    Name    = local.cart_sweeper_rule_name
    Service = "cart"
  }
}

resource "aws_cloudwatch_event_target" "cart_sweeper" {
  count = var.cart_sweeper_enabled ? 1 : 0

  rule      = aws_cloudwatch_event_rule.cart_sweeper[0].name
  target_id = "cart-sweeper"
  arn       = module.cart_delete_cart.function_arn

  input = jsonencode({
    source = "scheduled-sweep"
  })
}

resource "aws_lambda_permission" "cart_sweeper" {
  count = var.cart_sweeper_enabled ? 1 : 0

  statement_id  = "AllowInvokeFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = module.cart_delete_cart.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.cart_sweeper[0].arn
}
