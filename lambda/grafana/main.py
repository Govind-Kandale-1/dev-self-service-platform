import json
import os
import urllib.request
import urllib.error

import boto3

sm = boto3.client("secretsmanager")

_grafana_config = None


def handler(event, context):
    cfg       = _get_config()
    dashboard = _build_dashboard(event["env_id"], event["team"], event["project"])
    url       = _provision_dashboard(cfg, dashboard)

    return {
        **event,
        "dashboard_url": url,
    }


def _get_config():
    global _grafana_config
    if _grafana_config is None:
        secret = sm.get_secret_value(SecretId="idp/grafana-credentials")
        _grafana_config = json.loads(secret["SecretString"])
    return _grafana_config


def _provision_dashboard(cfg, dashboard):
    payload = json.dumps({
        "dashboard": dashboard,
        "overwrite": False,
        "folderId":  0,
    }).encode()

    req = urllib.request.Request(
        f"{cfg['url'].rstrip('/')}/api/dashboards/db",
        data=payload,
        headers={
            "Authorization": f"Bearer {cfg['api_key']}",
            "Content-Type":  "application/json",
        },
        method="POST",
    )

    with urllib.request.urlopen(req) as resp:
        data = json.loads(resp.read())

    return f"{cfg['url'].rstrip('/')}{data['url']}"


def _build_dashboard(env_id, team, project):
    namespace = f"{team}-{project}-{env_id}"
    title     = f"IDP | {namespace}"

    def panel(pid, title_, expr, unit, x, y):
        return {
            "id":         pid,
            "title":      title_,
            "type":       "timeseries",
            "gridPos":    {"x": x, "y": y, "w": 8, "h": 8},
            "datasource": {"type": "prometheus", "uid": "${datasource}"},
            "fieldConfig": {
                "defaults": {
                    "unit": unit,
                    "custom": {"lineWidth": 2},
                }
            },
            "targets": [{
                "expr":         expr,
                "legendFormat": "{{pod}}",
                "refId":        "A",
            }],
        }

    return {
        "title":         title,
        "uid":           f"idp-{env_id}",
        "schemaVersion": 39,
        "refresh":       "30s",
        "time":          {"from": "now-1h", "to": "now"},
        "templating": {
            "list": [{
                "name":        "datasource",
                "type":        "datasource",
                "pluginId":    "prometheus",
                "hide":        0,
                "includeAll":  False,
            }]
        },
        "panels": [
            panel(
                1, "CPU Usage (cores)",
                f'sum(rate(container_cpu_usage_seconds_total{{namespace="{namespace}",container!=""}}[5m])) by (pod)',
                "short", 0, 0,
            ),
            panel(
                2, "Memory Usage",
                f'sum(container_memory_working_set_bytes{{namespace="{namespace}",container!=""}}) by (pod)',
                "bytes", 8, 0,
            ),
            panel(
                3, "Pod Count",
                f'count(kube_pod_info{{namespace="{namespace}"}})',
                "short", 16, 0,
            ),
            panel(
                4, "Restarts",
                f'sum(increase(kube_pod_container_status_restarts_total{{namespace="{namespace}"}}[1h])) by (pod)',
                "short", 0, 8,
            ),
            panel(
                5, "Network Rx",
                f'sum(rate(container_network_receive_bytes_total{{namespace="{namespace}"}}[5m])) by (pod)',
                "Bps", 8, 8,
            ),
            panel(
                6, "Network Tx",
                f'sum(rate(container_network_transmit_bytes_total{{namespace="{namespace}"}}[5m])) by (pod)',
                "Bps", 16, 8,
            ),
        ],
        "annotations": {
            "list": [{
                "builtIn": 1,
                "datasource": {"type": "grafana", "uid": "-- Grafana --"},
                "enable": True,
                "hide": True,
                "name": "Annotations & Alerts",
                "type": "dashboard",
            }]
        },
        "tags": ["idp", team, project, env_id],
    }
