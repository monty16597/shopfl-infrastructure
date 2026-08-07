########################################
# Platform hygiene checker
#
# Runs on a schedule, inspects estate configuration that degrades quietly, and
# publishes the findings as metrics so they can be alarmed on.
########################################

data "archive_file" "config_check" {
  type        = "zip"
  source_dir  = "${path.module}/config_check"
  output_path = "${path.module}/.terraform/config_check.zip"
}

resource "aws_iam_role" "config_check" {
  name = "${local.name_prefix}-platform-${var.env}-config-check"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "config_check" {
  name = "${local.name_prefix}-platform-${var.env}-config-check"
  role = aws_iam_role.config_check.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "Logging"
        Effect   = "Allow"
        Action   = ["logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = "${aws_cloudwatch_log_group.config_check.arn}:*"
      },
      {
        Sid      = "InspectLogGroups"
        Effect   = "Allow"
        Action   = ["logs:DescribeLogGroups"]
        Resource = "*"
      },
      {
        Sid      = "InspectBucket"
        Effect   = "Allow"
        Action   = ["s3:GetBucketPublicAccessBlock", "s3:GetLifecycleConfiguration"]
        Resource = aws_s3_bucket.products.arn
      },
      {
        Sid      = "InspectTables"
        Effect   = "Allow"
        Action   = ["dynamodb:DescribeTable"]
        Resource = aws_dynamodb_table.carts.arn
      },
    ]
  })
}

resource "aws_cloudwatch_log_group" "config_check" {
  name = "/aws/lambda/${local.name_prefix}-platform-${var.env}-config-check"

  tags = {
    Service = "platform"
    Env     = var.env
  }
}

resource "aws_lambda_function" "config_check" {
  function_name = "${local.name_prefix}-platform-${var.env}-config-check"
  role          = aws_iam_role.config_check.arn
  handler       = "index.handler"
  runtime       = "python3.12"
  timeout       = 60
  memory_size   = 256

  filename         = data.archive_file.config_check.output_path
  source_code_hash = data.archive_file.config_check.output_base64sha256

  environment {
    variables = {
      ENV              = var.env
      LOG_GROUP_PREFIX = "/aws/lambda/${local.name_prefix}-"
      PRODUCTS_BUCKET  = aws_s3_bucket.products.bucket
      CARTS_TABLE      = aws_dynamodb_table.carts.name
    }
  }

  depends_on = [aws_cloudwatch_log_group.config_check]

  tags = {
    Service = "platform"
    Env     = var.env
  }
}

resource "aws_cloudwatch_event_rule" "config_check" {
  name                = "${local.name_prefix}-platform-${var.env}-config-check"
  description         = "Periodic platform configuration hygiene check"
  schedule_expression = var.config_check_schedule
}

resource "aws_cloudwatch_event_target" "config_check" {
  rule      = aws_cloudwatch_event_rule.config_check.name
  target_id = "config-check"
  arn       = aws_lambda_function.config_check.arn
}

resource "aws_lambda_permission" "config_check" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.config_check.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.config_check.arn
}
