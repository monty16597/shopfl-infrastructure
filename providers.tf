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

data "aws_sns_topic" "incidents" {
  name = var.incident_topic_name
}
