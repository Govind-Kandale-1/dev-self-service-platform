import json
import os

import boto3

ses = boto3.client("ses")
sm  = boto3.client("secretsmanager")

_ses_config = None


def _get_ses_config():
    global _ses_config
    if _ses_config is None:
        secret = sm.get_secret_value(SecretId="idp/ses-config")
        _ses_config = json.loads(secret["SecretString"])
    return _ses_config


def handler(event, context):
    cfg        = _get_ses_config()
    namespace  = f"{event['team']}-{event['project']}-{event['env_id']}"
    dashboard  = event.get("grafana_dashboard_url", "—")
    group      = event.get("entra_group_name", "—")

    body = f"""Your environment is ready.

Namespace:       {namespace}
Environment ID:  {event['env_id']}
Entra ID Group:  {group}
Grafana:         {dashboard}

kubeconfig snippet
------------------
aws eks update-kubeconfig \\
  --name <cluster-name> \\
  --region eu-west-1

kubectl config set-context --current --namespace={namespace}

Resource limits
---------------
CPU:    {event.get('cpu_limit', '2')} cores
Memory: {event.get('memory_limit', '2Gi')}

--
Dev Self-Service Platform
"""

    ses.send_email(
        Source=cfg["from_email"],
        Destination={"ToAddresses": [event["owner_email"]]},
        Message={
            "Subject": {"Data": f"[IDP] Environment {event['env_id']} is ready"},
            "Body":    {"Text": {"Data": body}},
        },
    )

    return {**event, "notified": True}
