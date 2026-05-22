import json
import os
from datetime import datetime, timezone

import boto3

ddb = boto3.resource("dynamodb")


def handler(event, context):
    table = ddb.Table(os.environ["TABLE_NAME"])

    updates = {
        "status":     event.get("status", "READY"),
        "updated_at": datetime.now(timezone.utc).isoformat(),
    }

    if "error" in event:
        updates["error"] = json.dumps(event["error"])

    if "group_id" in event:
        updates["entra_group_id"] = event["group_id"]

    if "dashboard_url" in event:
        updates["grafana_dashboard_url"] = event["dashboard_url"]

    expr_parts = [f"#{k} = :{k}" for k in updates]
    table.update_item(
        Key={"env_id": event["env_id"]},
        UpdateExpression="SET " + ", ".join(expr_parts),
        ExpressionAttributeNames={f"#{k}": k for k in updates},
        ExpressionAttributeValues={f":{k}": v for k, v in updates.items()},
    )

    return {**event, **updates}
