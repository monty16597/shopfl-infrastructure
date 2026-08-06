resource "aws_sqs_queue" "payment_requests_dlq" {
  name                      = local.queue_names.payment_requests_dlq
  message_retention_seconds = 1209600

  tags = {
    Name    = local.queue_names.payment_requests_dlq
    Service = "payment"
  }
}

resource "aws_sqs_queue" "payment_requests" {
  name                       = local.queue_names.payment_requests
  visibility_timeout_seconds = var.queue_visibility_timeout_s
  message_retention_seconds  = 345600

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.payment_requests_dlq.arn
    maxReceiveCount     = var.queue_max_receive_count
  })

  tags = {
    Name    = local.queue_names.payment_requests
    Service = "payment"
  }
}

resource "aws_sqs_queue" "notifications_dlq" {
  name                      = local.queue_names.notifications_dlq
  message_retention_seconds = 1209600

  tags = {
    Name    = local.queue_names.notifications_dlq
    Service = "notification"
  }
}

resource "aws_sqs_queue" "notifications" {
  name                       = local.queue_names.notifications
  visibility_timeout_seconds = var.queue_visibility_timeout_s
  message_retention_seconds  = 345600

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.notifications_dlq.arn
    maxReceiveCount     = var.queue_max_receive_count
  })

  tags = {
    Name    = local.queue_names.notifications
    Service = "notification"
  }
}
