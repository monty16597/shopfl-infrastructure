########################################
# Core
########################################

variable "region" {
  description = "AWS region for every resource in this configuration."
  type        = string
  default     = "us-east-1"
}

variable "env" {
  description = "Environment suffix used in every resource name."
  type        = string
  default     = "dev"
}

variable "artifact_root" {
  description = "Directory that contains the service repositories holding built Lambda artifacts."
  type        = string
  default     = ".."
}

########################################
# Incident notification topic
########################################

variable "incident_topic_name" {
  description = "Name of the pre-existing SNS topic that receives CloudWatch alarm notifications."
  type        = string
  default     = "OpsFabric-Incidents"
}

variable "payment_queue_age_p0_threshold_s" {
  description = "Age of the oldest unprocessed payment request, in seconds, that counts as revenue blocking."
  type        = number
  default     = 900
}

variable "auth_timezone" {
  description = "TZ for the auth functions. Lambda defaults to UTC."
  type        = string
  default     = "UTC"
}

variable "alarm_notifications_enabled" {
  description = "When false, alarms still evaluate and change state but publish to no destination."
  type        = bool
  default     = false
}

variable "incident_topic_arn" {
  description = "Optional explicit ARN for the incident topic. When null the ARN is looked up by name."
  type        = string
  default     = null
  nullable    = true
}

########################################
# DynamoDB
########################################

variable "table_billing_mode" {
  description = "Billing mode applied to the users, products, carts, payments and idempotency tables."
  type        = string
  default     = "PAY_PER_REQUEST"
}

variable "orders_billing_mode" {
  description = "Billing mode for the orders table."
  type        = string
  default     = "PAY_PER_REQUEST"
}

variable "orders_read_capacity" {
  description = "Provisioned read capacity units for the orders table when billing mode is PROVISIONED."
  type        = number
  default     = 5
}

variable "orders_write_capacity" {
  description = "Provisioned write capacity units for the orders table when billing mode is PROVISIONED."
  type        = number
  default     = 5
}

########################################
# Lambda sizing
########################################

variable "default_memory_mb" {
  description = "Default Lambda memory size in megabytes."
  type        = number
  default     = 512
}

variable "default_timeout_s" {
  description = "Default Lambda timeout in seconds."
  type        = number
  default     = 10
}

variable "catalog_memory_mb" {
  description = "Memory size in megabytes for catalog-service functions."
  type        = number
  default     = 512
}

variable "order_timeout_s" {
  description = "Timeout in seconds for order-service functions."
  type        = number
  default     = 15
}

variable "cart_reserved_concurrency" {
  description = "Reserved concurrent executions for cart-service functions. -1 leaves concurrency unreserved."
  type        = number
  default     = -1
}

########################################
# IAM
########################################

variable "order_role_allow_put_item" {
  description = "Whether the order-service execution role may call dynamodb:PutItem on the orders table."
  type        = bool
  default     = true
}

########################################
# Messaging
########################################

variable "queue_visibility_timeout_s" {
  description = "Visibility timeout in seconds for the payment and notification queues."
  type        = number
  default     = 60
}

variable "queue_max_receive_count" {
  description = "Number of receives before a message is moved to its dead letter queue."
  type        = number
  default     = 3
}

variable "payment_esm_enabled" {
  description = "Whether the payment-service SQS event source mapping is enabled."
  type        = bool
  default     = true
}

variable "payment_esm_batch_size" {
  description = "Batch size for the payment-service SQS event source mapping."
  type        = number
  default     = 5
}

variable "notification_esm_batch_size" {
  description = "Batch size for the notification-service SQS event source mapping."
  type        = number
  default     = 5
}

########################################
# Gateway
########################################

variable "gateway_secret_name" {
  description = "Secrets Manager secret name holding the payment gateway API key."
  type        = string
  default     = "shopfl-gateway-key-dev"
}

variable "gateway_latency_ms" {
  description = "Simulated latency in milliseconds applied by the mock payment gateway."
  type        = number
  default     = 120
}

variable "gateway_failure_rate" {
  description = "Fraction of mock payment gateway charges that are declined."
  type        = number
  default     = 0.02
}

########################################
# Storage
########################################

variable "products_bucket_public_block" {
  description = "Whether a public access block is applied to the product media bucket."
  type        = bool
  default     = true
}

variable "products_bucket_lifecycle_enabled" {
  description = "Whether the product media bucket has a lifecycle configuration."
  type        = bool
  default     = true
}

variable "products_bucket_expiration_days" {
  description = "Age in days at which noncurrent product media object versions expire."
  type        = number
  default     = 90
}

########################################
# Scheduling
########################################

variable "cart_sweeper_enabled" {
  description = "Whether the scheduled cart sweeper rule is created and enabled."
  type        = bool
  default     = true
}

variable "cart_sweeper_schedule" {
  description = "Schedule expression for the cart sweeper rule."
  type        = string
  default     = "rate(1 day)"
}

########################################
# Application settings
########################################

variable "jwt_secret" {
  description = "HS256 signing secret used by auth-service tokens."
  type        = string
  default     = "shopfl-dev-signing-key"
  sensitive   = true
}

variable "token_ttl_min" {
  description = "Lifetime in minutes of an issued access token."
  type        = number
  default     = 60
}

variable "log_level" {
  description = "Log level exported to every Lambda function."
  type        = string
  default     = "INFO"
}

variable "ses_enabled" {
  description = "Whether notification-service sends email through SES."
  type        = bool
  default     = false
}

variable "ses_sender" {
  description = "From address used by notification-service when SES is enabled."
  type        = string
  default     = "no-reply@shopfl.example"
}

########################################
# Alarm thresholds
########################################

variable "alarm_period_s" {
  description = "Default period in seconds for CloudWatch alarms."
  type        = number
  default     = 300
}

variable "lambda_error_threshold" {
  description = "Lambda Errors sum over one period that raises a P0 alarm."
  type        = number
  default     = 5
}

variable "lambda_error_rate_threshold" {
  description = "Lambda error percentage over one period that raises a P0 alarm."
  type        = number
  default     = 5
}

variable "lambda_throttle_threshold" {
  description = "Lambda Throttles sum over one period that raises a P1 alarm."
  type        = number
  default     = 1
}

variable "lambda_duration_p99_ms" {
  description = "Lambda p99 duration in milliseconds that raises a P1 alarm."
  type        = number
  default     = 3000
}

variable "api_5xx_threshold" {
  description = "API Gateway 5xx responses over one period that raise a P0 alarm."
  type        = number
  default     = 5
}

variable "dlq_depth_threshold" {
  description = "Visible messages on a dead letter queue that raise a P0 alarm."
  type        = number
  default     = 1
}

variable "queue_age_threshold_s" {
  description = "Age in seconds of the oldest queue message that raises a P1 alarm."
  type        = number
  default     = 300
}

variable "dynamodb_throttle_threshold" {
  description = "DynamoDB ThrottledRequests over one period that raise a P0 alarm."
  type        = number
  default     = 1
}

variable "eventbridge_failure_threshold" {
  description = "EventBridge FailedInvocations over one period that raise a P1 alarm."
  type        = number
  default     = 1
}

variable "warn_rate_threshold" {
  description = "WARNING log lines over one period that raise a P2 alarm."
  type        = number
  default     = 50
}

variable "email_pattern_threshold" {
  description = "Log lines matching an email address pattern over one period that raise a P2 alarm."
  type        = number
  default     = 1
}

variable "event_delivery_delta_threshold" {
  description = "Difference between published order events and sent notifications that raises a P2 alarm."
  type        = number
  default     = 5
}
