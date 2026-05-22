import json
import os

import boto3
import urllib.request
import urllib.parse
import urllib.error

sm = boto3.client("secretsmanager")

_credentials = None
GRAPH_API = "https://graph.microsoft.com/v1.0"


def handler(event, context):
    creds      = _get_credentials()
    token      = _get_token(creds["tenant_id"], creds["client_id"], creds["client_secret"])
    group_name = f"idp-{event['team']}-{event['project']}-{event['env_id']}"

    group_id = _create_group(token, group_name, event["team"], event["project"])
    _assign_owner(token, group_id, event["owner_email"])

    return {
        **event,
        "group_id":   group_id,
        "group_name": group_name,
    }


def _get_credentials():
    global _credentials
    if _credentials is None:
        secret = sm.get_secret_value(SecretId="idp/entra-credentials")
        _credentials = json.loads(secret["SecretString"])
    return _credentials


def _get_token(tenant_id, client_id, client_secret):
    url  = f"https://login.microsoftonline.com/{tenant_id}/oauth2/v2.0/token"
    data = urllib.parse.urlencode({
        "grant_type":    "client_credentials",
        "client_id":     client_id,
        "client_secret": client_secret,
        "scope":         "https://graph.microsoft.com/.default",
    }).encode()

    req  = urllib.request.Request(url, data=data, method="POST")
    resp = _http(req)
    return resp["access_token"]


def _create_group(token, name, team, project):
    payload = {
        "displayName":     name,
        "mailEnabled":     False,
        "mailNickname":    name.replace("-", ""),
        "securityEnabled": True,
        "description":     f"IDP-managed group for team={team} project={project}",
    }
    req = urllib.request.Request(
        f"{GRAPH_API}/groups",
        data=json.dumps(payload).encode(),
        headers={"Authorization": f"Bearer {token}", "Content-Type": "application/json"},
        method="POST",
    )
    resp = _http(req)
    return resp["id"]


def _assign_owner(token, group_id, owner_email):
    user = _get_user_id(token, owner_email)
    if not user:
        return

    payload = {"@odata.id": f"{GRAPH_API}/directoryObjects/{user}"}
    req = urllib.request.Request(
        f"{GRAPH_API}/groups/{group_id}/owners/$ref",
        data=json.dumps(payload).encode(),
        headers={"Authorization": f"Bearer {token}", "Content-Type": "application/json"},
        method="POST",
    )
    try:
        _http(req)
    except urllib.error.HTTPError as e:
        if e.code != 400:
            raise


def _get_user_id(token, email):
    req = urllib.request.Request(
        f"{GRAPH_API}/users/{urllib.parse.quote(email)}?$select=id",
        headers={"Authorization": f"Bearer {token}"},
    )
    try:
        resp = _http(req)
        return resp.get("id")
    except urllib.error.HTTPError:
        return None


def _http(req):
    with urllib.request.urlopen(req) as resp:
        body = resp.read()
        return json.loads(body) if body else {}
