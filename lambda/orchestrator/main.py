import json
import os
import uuid
from datetime import datetime, timezone

import boto3

sfn = boto3.client("stepfunctions")
ddb = boto3.resource("dynamodb")


def handler(event, context):
    if event.get("httpMethod") == "OPTIONS":
        return _cors(200, "")

    try:
        body = json.loads(event.get("body") or "{}")
    except json.JSONDecodeError:
        return _cors(400, json.dumps({"message": "Invalid JSON body"}))

    missing = [f for f in ("team", "project", "owner_email") if not body.get(f)]
    if missing:
        return _cors(400, json.dumps({"message": f"Missing fields: {', '.join(missing)}"}))

    env_id = uuid.uuid4().hex[:8]
    payload = {
        "env_id":       env_id,
        "team":         body["team"].lower().strip(),
        "project":      body["project"].lower().strip(),
        "owner_email":  body["owner_email"].strip(),
        "cpu_limit":    body.get("cpu_limit", "2"),
        "memory_limit": body.get("memory_limit", "2Gi"),
    }

    table = ddb.Table(os.environ["TABLE_NAME"])
    table.put_item(Item={
        **payload,
        "status":     "PROVISIONING",
        "created_at": datetime.now(timezone.utc).isoformat(),
    })

    sfn.start_execution(
        stateMachineArn=os.environ["STATE_MACHINE_ARN"],
        name=f"provision-{env_id}",
        input=json.dumps(payload),
    )

    return _cors(202, json.dumps({"env_id": env_id, "status": "PROVISIONING"}))


def _cors(status, body):
    return {
        "statusCode": status,
        "headers": {
            "Content-Type":                "application/json",
            "Access-Control-Allow-Origin":  "*",
            "Access-Control-Allow-Headers": "Content-Type",
            "Access-Control-Allow-Methods": "POST,OPTIONS",
        },
        "body": body,
    }
