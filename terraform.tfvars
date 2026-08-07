region        = "us-east-2"
env           = "dev"
artifact_root = ".."

incident_topic_name         = "OpsFabric-Incidents"
alarm_notifications_enabled = true

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
