"""Periodic platform hygiene checks.

Inspects the estate for configuration that drifts silently rather than failing
loudly - log groups that never expire, storage that is not locked down, tables
that only ever grow - and publishes the findings as CloudWatch metrics so they
can be alarmed on like anything else.
"""

import json
import os
import sys
import time

import boto3

NAMESPACE = "ShopFL/Config"
ENV = os.environ.get("ENV", "dev")
LOG_GROUP_PREFIX = os.environ.get("LOG_GROUP_PREFIX", "/aws/lambda/shopfl-")
PRODUCTS_BUCKET = os.environ["PRODUCTS_BUCKET"]
CARTS_TABLE = os.environ["CARTS_TABLE"]

logs = boto3.client("logs")
s3 = boto3.client("s3")
dynamodb = boto3.client("dynamodb")


def _emit(metric, value, unit="Count"):
    sys.stdout.write(
        json.dumps(
            {
                "_aws": {
                    "Timestamp": int(time.time() * 1000),
                    "CloudWatchMetrics": [
                        {
                            "Namespace": NAMESPACE,
                            "Dimensions": [["env"]],
                            "Metrics": [{"Name": metric, "Unit": unit}],
                        }
                    ],
                },
                "env": ENV,
                metric: value,
            }
        )
        + "\n"
    )


def _log(event, **fields):
    sys.stdout.write(json.dumps({"event": event, "env": ENV, **fields}) + "\n")


def check_log_retention():
    """Count log groups that will retain their data forever."""
    unbounded = []
    paginator = logs.get_paginator("describe_log_groups")
    for page in paginator.paginate(logGroupNamePrefix=LOG_GROUP_PREFIX):
        for group in page["logGroups"]:
            if not group.get("retentionInDays"):
                unbounded.append(group["logGroupName"])

    _log("log_retention_checked", unbounded_count=len(unbounded), unbounded=unbounded[:20])
    _emit("log_groups_without_retention", len(unbounded))
    return len(unbounded)


def check_bucket_config():
    """Count storage findings on the product image bucket."""
    findings = []

    try:
        block = s3.get_public_access_block(Bucket=PRODUCTS_BUCKET)
        cfg = block["PublicAccessBlockConfiguration"]
        for key in ("BlockPublicAcls", "IgnorePublicAcls", "BlockPublicPolicy", "RestrictPublicBuckets"):
            if not cfg.get(key):
                findings.append(f"public_access_block.{key}=false")
    except s3.exceptions.ClientError:
        findings.append("public_access_block.missing")

    try:
        s3.get_bucket_lifecycle_configuration(Bucket=PRODUCTS_BUCKET)
    except s3.exceptions.ClientError:
        findings.append("lifecycle_configuration.missing")

    _log("bucket_config_checked", bucket=PRODUCTS_BUCKET, finding_count=len(findings), findings=findings)
    _emit("bucket_config_findings", len(findings))
    return len(findings)


def check_table_growth():
    """Report how many items the carts table is holding."""
    # Counted, not read off DescribeTable. DynamoDB refreshes Table.ItemCount roughly every six
    # hours, so it lags real growth by far more than P2-INFRA-03's 60-minute budget - it read 0
    # while the table genuinely held rows. A Select=COUNT scan is exact and current, and this
    # table is small precisely because the scenario is about it NOT staying small.
    item_count = 0
    kwargs = {"TableName": CARTS_TABLE, "Select": "COUNT"}
    while True:
        page = dynamodb.scan(**kwargs)
        item_count += page["Count"]
        last_key = page.get("LastEvaluatedKey")
        if not last_key:
            break
        kwargs["ExclusiveStartKey"] = last_key

    _log("table_growth_checked", table=CARTS_TABLE, item_count=item_count)
    _emit("carts_item_count", item_count)
    return item_count


def handler(event, context):
    results = {
        "log_groups_without_retention": check_log_retention(),
        "bucket_config_findings": check_bucket_config(),
        "carts_item_count": check_table_growth(),
    }
    _log("config_check_complete", **results)
    return results
