# shopfl-infrastructure

Terraform configuration for the ShopFL serverless e-commerce estate in `us-east-1`,
environment `dev`.

## What this provisions

**Compute and routing**

- Nineteen Python 3.12 Lambda functions, one per handler, named
  `shopfl-<service>-dev-<handler>`, each with its own IAM role, inline execution
  policy and CloudWatch log group.
- Seven HTTP APIs (API Gateway v2), one per service plus the mock payment gateway:
  `shopfl-auth-dev`, `shopfl-catalog-dev`, `shopfl-cart-dev`, `shopfl-order-dev`,
  `shopfl-payment-dev`, `shopfl-gateway-dev`, `shopfl-notification-dev`.
  Every API uses the `$default` stage with `auto_deploy`.
- Two SQS event source mappings: `shopfl-payment-dev-process-payment` on the payment
  request queue and `shopfl-notification-dev-consume-events` on the notification queue.

**State and messaging**

- Six DynamoDB tables: `shopfl-users-dev`, `shopfl-products-dev`, `shopfl-carts-dev`,
  `shopfl-orders-dev`, `shopfl-payments-dev`, `shopfl-idempotency-dev`.
- Two SQS queues, `shopfl-payment-requests-dev` and `shopfl-notifications-dev`, each
  with a dead letter queue and a redrive policy of three receives.
- SNS topic `shopfl-order-events-dev` with the notification queue subscribed and a
  queue policy allowing the topic to deliver.
- S3 bucket `shopfl-products-dev-<account_id>` for product media, with versioning,
  a public access block and a lifecycle configuration.
- Secrets Manager secret holding the payment gateway API key.
- EventBridge rule `shopfl-cart-sweeper-dev` on a daily schedule.

**Alerting**

CloudWatch alarms named `shopfl-<service>-dev-<p0|p1|p2>-<signal>` and tagged
`Severity`, `Service` and `Env`. Every alarm sends both its `alarm_actions` and
`ok_actions` to the pre-existing SNS topic `Opsfabric-Incidents`, which is read with
`data "aws_sns_topic"` and is never created or destroyed by this configuration.

| Signal | Severity | Source |
|---|---|---|
| `errors` | P0 | Lambda `Errors` |
| `error-rate` | P0 | Lambda `Errors` / `Invocations` metric math |
| `api-5xx` | P0 | API Gateway `5xx` |
| `dlq-depth` | P0 | SQS `ApproximateNumberOfMessagesVisible` on each DLQ |
| `table-throttles` | P0 | DynamoDB `ThrottledRequests` |
| `throttles` | P1 | Lambda `Throttles` |
| `duration-p99` | P1 | Lambda `Duration` p99 |
| `queue-age` | P1 | SQS `ApproximateAgeOfOldestMessage` |
| `rule-failed-invocations` | P1 | EventBridge `FailedInvocations` |
| `warn-rate` | P2 | Log metric filter on WARNING log lines |
| `email-pattern` | P2 | Log metric filter matching email addresses in log payloads |
| `event-delivery-delta` | P2 | `order_events_published` minus `notifications_sent` metric math |

## Layout

Terraform loads every `.tf` file in a single directory as one module and does not
descend into subdirectories, so the root module is flat and files are grouped by
filename prefix instead of by folder:

```
versions.tf providers.tf variables.tf locals.tf outputs.tf terraform.tfvars
shared_dynamodb.tf shared_sqs.tf shared_sns.tf shared_s3.tf shared_secrets.tf shared_eventbridge.tf
service_auth.tf service_catalog.tf service_cart.tf service_order.tf service_payment.tf service_notification.tf
alarms_p0.tf alarms_p1.tf alarms_p2.tf
modules/lambda_service/{main.tf,variables.tf,outputs.tf}
modules/alarms/{main.tf,variables.tf}
```

`modules/` holds real child modules invoked with `source = "./modules/..."`.

## Prerequisites

- Terraform >= 1.6
- AWS credentials for a single account with permission to manage Lambda, API Gateway,
  DynamoDB, SQS, SNS, S3, Secrets Manager, EventBridge, CloudWatch and IAM
- An existing SNS topic named `Opsfabric-Incidents` in `us-east-1`
- Python 3.12 and `make` to build the service artifacts

## Build the service artifacts first

Every Lambda function is deployed from a zip built by its own service repository.
Terraform reads them from `${var.artifact_root}/shopfl-<service>-service/dist/shopfl-<service>.zip`,
with `artifact_root` defaulting to `..`. Build all six before planning:

```bash
cd ..
for r in auth catalog cart order payment notification; do
  (cd shopfl-$r-service && make build)
done
ls -l shopfl-*-service/dist/*.zip
```

## Deploy

```bash
cd shopfl-infrastructure
terraform init
terraform plan
terraform apply
terraform output -json
```

To validate without contacting a backend or AWS:

```bash
terraform init -backend=false
terraform validate
terraform fmt -check -recursive
```

## Remote state

State is held in S3 and configured in `backend.tf`:

| Setting | Value |
|---|---|
| Bucket | `devops-project-terraform-remote-backend` |
| Key | `shopfl/dev/terraform.tfstate` |
| Bucket region | `ca-central-1` |
| Locking | S3 native (`use_lockfile`), no DynamoDB table |

The bucket lives in `ca-central-1` while the resources are created in `us-east-1` — the
backend region is independent of the provider region. The bucket is versioned, so a corrupted
or truncated state can be rolled back to a previous object version.

The bucket is shared with unrelated projects, which is why the key is namespaced under
`shopfl/`. Do not change the key without migrating state first (`terraform init -migrate-state`).

`.terraform.lock.hcl` is committed so provider versions resolve identically for everyone
working against this shared state.

## Outputs

| Output | Description |
|---|---|
| `auth_base_url` | Base URL of the auth-service HTTP API |
| `catalog_base_url` | Base URL of the catalog-service HTTP API |
| `cart_base_url` | Base URL of the cart-service HTTP API |
| `order_base_url` | Base URL of the order-service HTTP API |
| `payment_base_url` | Base URL of the payment-service HTTP API |
| `gateway_base_url` | Base URL of the mock payment gateway HTTP API |
| `notification_base_url` | Base URL of the notification-service HTTP API |
| `payment_queue_url` | Payment request queue URL |
| `payment_dlq_url` | Payment request dead letter queue URL |
| `notification_queue_url` | Notification queue URL |
| `notification_dlq_url` | Notification dead letter queue URL |
| `order_events_topic_arn` | Order events topic ARN |
| `products_bucket_name` | Product media bucket name |
| `gateway_secret_name` | Gateway API key secret name |
| `incident_topic_arn` | ARN wired to every alarm action |
| `table_names` | Map of logical name to DynamoDB table name |
| `lambda_function_names` | Map of service and handler to Lambda function name |
| `log_group_names` | Map of service and handler to log group name |

## Variable reference

### Core

| Variable | Type | Default | Description |
|---|---|---|---|
| `region` | string | `us-east-1` | AWS region |
| `env` | string | `dev` | Environment suffix in every resource name |
| `artifact_root` | string | `..` | Directory holding the service repositories |

### Incident notification topic

| Variable | Type | Default | Description |
|---|---|---|---|
| `incident_topic_name` | string | `Opsfabric-Incidents` | Name of the existing alarm topic |
| `incident_topic_arn` | string | `null` | Explicit ARN override; looked up by name when null |

### DynamoDB

| Variable | Type | Default | Description |
|---|---|---|---|
| `table_billing_mode` | string | `PAY_PER_REQUEST` | Billing mode for users, products, carts, payments and idempotency |
| `orders_billing_mode` | string | `PAY_PER_REQUEST` | Billing mode for the orders table |
| `orders_read_capacity` | number | `5` | Orders read capacity when provisioned |
| `orders_write_capacity` | number | `5` | Orders write capacity when provisioned |

### Lambda sizing

| Variable | Type | Default | Description |
|---|---|---|---|
| `default_memory_mb` | number | `512` | Default function memory |
| `default_timeout_s` | number | `10` | Default function timeout |
| `catalog_memory_mb` | number | `512` | Memory for catalog-service functions |
| `order_timeout_s` | number | `15` | Timeout for order-service functions |
| `cart_reserved_concurrency` | number | `-1` | Reserved concurrency for cart-service functions; -1 leaves it unreserved |

### IAM

| Variable | Type | Default | Description |
|---|---|---|---|
| `order_role_allow_put_item` | bool | `true` | Whether the order-service role may call `dynamodb:PutItem` on the orders table |

### Messaging

| Variable | Type | Default | Description |
|---|---|---|---|
| `queue_visibility_timeout_s` | number | `60` | Visibility timeout for both work queues |
| `queue_max_receive_count` | number | `3` | Receives before a message moves to its DLQ |
| `payment_esm_enabled` | bool | `true` | Whether the payment event source mapping is enabled |
| `payment_esm_batch_size` | number | `5` | Payment event source mapping batch size |
| `notification_esm_batch_size` | number | `5` | Notification event source mapping batch size |

### Gateway

| Variable | Type | Default | Description |
|---|---|---|---|
| `gateway_secret_name` | string | `shopfl-gateway-key-dev` | Secrets Manager secret holding the gateway API key |
| `gateway_latency_ms` | number | `120` | Simulated gateway latency |
| `gateway_failure_rate` | number | `0.02` | Fraction of charges the mock gateway declines |

### Storage

| Variable | Type | Default | Description |
|---|---|---|---|
| `products_bucket_public_block` | bool | `true` | Whether a public access block is applied |
| `products_bucket_lifecycle_enabled` | bool | `true` | Whether a lifecycle configuration is applied |
| `products_bucket_expiration_days` | number | `90` | Age at which noncurrent versions expire |

### Scheduling

| Variable | Type | Default | Description |
|---|---|---|---|
| `cart_sweeper_enabled` | bool | `true` | Whether the cart sweeper rule is created and enabled |
| `cart_sweeper_schedule` | string | `rate(1 day)` | Schedule expression for the sweeper |

### Application settings

| Variable | Type | Default | Description |
|---|---|---|---|
| `jwt_secret` | string (sensitive) | `shopfl-dev-signing-key` | HS256 token signing secret |
| `token_ttl_min` | number | `60` | Access token lifetime in minutes |
| `log_level` | string | `INFO` | Log level exported to every function |
| `ses_enabled` | bool | `false` | Whether notification-service sends through SES |
| `ses_sender` | string | `no-reply@shopfl.example` | From address when SES is enabled |

### Alarm thresholds

| Variable | Type | Default | Description |
|---|---|---|---|
| `alarm_period_s` | number | `300` | Default alarm period |
| `lambda_error_threshold` | number | `5` | Lambda errors per period |
| `lambda_error_rate_threshold` | number | `5` | Lambda error percentage per period |
| `lambda_throttle_threshold` | number | `1` | Lambda throttles per period |
| `lambda_duration_p99_ms` | number | `3000` | p99 duration in milliseconds |
| `api_5xx_threshold` | number | `5` | API Gateway 5xx responses per period |
| `dlq_depth_threshold` | number | `1` | Visible messages on a dead letter queue |
| `queue_age_threshold_s` | number | `300` | Age of the oldest queue message |
| `dynamodb_throttle_threshold` | number | `1` | DynamoDB throttled requests per period |
| `eventbridge_failure_threshold` | number | `1` | EventBridge failed invocations per period |
| `warn_rate_threshold` | number | `50` | WARNING log lines per period |
| `email_pattern_threshold` | number | `1` | Log lines matching an email address pattern |
| `event_delivery_delta_threshold` | number | `5` | Published order events minus sent notifications |
