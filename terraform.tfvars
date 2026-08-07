region        = "us-east-2"
env           = "dev"
artifact_root = ".."

incident_topic_name         = "OpsFabric-Incidents"
alarm_notifications_enabled = false

table_billing_mode  = "PAY_PER_REQUEST"
orders_billing_mode = "PAY_PER_REQUEST"

catalog_memory_mb         = 512
order_timeout_s           = 15
cart_reserved_concurrency = -1

order_role_allow_put_item = true
payment_esm_enabled       = true

gateway_secret_name = "shopfl-gateway-key-dev"
gateway_latency_ms  = 120

products_bucket_public_block      = true
products_bucket_lifecycle_enabled = true

cart_sweeper_enabled = true

# Only these alarms publish. One scenario at a time.
notify_alarm_names = []

# rate(1 day) makes the sweeper untestable - FailedInvocations would not appear
# for up to 24 hours. Two minutes keeps the scenario exercisable.
cart_sweeper_schedule = "rate(1 day)"
