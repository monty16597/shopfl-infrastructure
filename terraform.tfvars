region        = "us-east-1"
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

# 300s, not the 3600s default.
#
# P2-OPS-02's alarm is ApproximateAgeOfOldestMessage on the payment DLQ, and its P2 budget is 60
# minutes. At a 3600s threshold the alarm cannot fire until the budget is exactly spent — the same
# threshold-equals-budget collision as P0-INFRA-03. SQS SentTimestamp cannot be backdated, so the
# only way to make a "stale dead letter" scenario observable on demand is to scale the threshold.
# The reasoning being graded — triage the DLQ before the messages expire — is unchanged.
dlq_age_threshold_s = 300

cart_sweeper_enabled = true

# 500 rows, not the 5000 default.
#
# P2-INFRA-03 alarms on how many rows shopfl-carts-dev is holding. The table is keyed on user_id
# alone and the seed creates 20 users, so before the abandoned_carts profile existed the table
# could not exceed 20 rows - the default threshold was unreachable by a factor of 250 and the
# scenario could never fire. 500 is comfortably above anything the other profiles produce (they
# reuse the same 20 ids) and is reached about a minute into abandoned-cart traffic, well inside
# the 60-minute P2 budget. The reasoning being graded - expires_at written, TTL never enabled,
# so nothing reclaims the rows - is unchanged.
carts_item_count_threshold = 500

# rate(5 minutes), not the rate(1 day) default.
#
# P2-OPS-01's alarm watches AWS/Events FailedInvocations on this rule, so the signal cannot exist
# until the rule next fires. On a daily cadence that is up to 24 hours against a 60-minute P2
# budget — the scenario was unrunnable, not merely slow. The reasoning being graded (a scheduled
# job silently stopping) is unaffected by how often it is scheduled. This mirrors P2-OPS-02, whose
# DLQ-age threshold is already time-scaled to minutes for exactly the same reason.
cart_sweeper_schedule = "rate(5 minutes)"

# Empty means EVERY alarm publishes. Narrowing this to a single name silently disarms the other
# 23 scenarios — their alarms still evaluate and still go to ALARM, but nothing is notified, so a
# run looks like a detection failure when it is really a configuration one.
notify_alarm_names = []
