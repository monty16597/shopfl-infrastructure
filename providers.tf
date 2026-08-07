provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Project   = "shopfl"
      Env       = var.env
      ManagedBy = "terraform"
    }
  }
}

data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

# Looked up only when alarms actually publish. CloudWatch requires an alarm's
# SNS target to live in the alarm's own region, so the topic must exist in
# var.region before notifications can be turned on.
data "aws_sns_topic" "incidents" {
  count = var.alarm_notifications_enabled && var.incident_topic_arn == null ? 1 : 0

  name = var.incident_topic_name
}
