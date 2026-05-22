import json
import os
from unittest.mock import MagicMock, patch

import pytest

os.environ.setdefault("TABLE_NAME", "test-table")
os.environ.setdefault("STATE_MACHINE_ARN", "arn:aws:states:eu-west-1:123456789012:stateMachine:test")

from main import handler


def _event(body):
    return {"httpMethod": "POST", "body": json.dumps(body)}


@patch("main.sfn")
@patch("main.ddb")
def test_valid_request(mock_ddb, mock_sfn):
    mock_ddb.Table.return_value.put_item = MagicMock()
    mock_sfn.start_execution = MagicMock()

    resp = handler(_event({"team": "payments", "project": "api", "owner_email": "a@b.com"}), {})

    assert resp["statusCode"] == 202
    data = json.loads(resp["body"])
    assert "env_id" in data
    assert len(data["env_id"]) == 8


@patch("main.sfn")
@patch("main.ddb")
def test_missing_fields(mock_ddb, mock_sfn):
    resp = handler(_event({"team": "payments"}), {})
    assert resp["statusCode"] == 400
    assert "project" in json.loads(resp["body"])["message"]


def test_options_preflight():
    resp = handler({"httpMethod": "OPTIONS"}, {})
    assert resp["statusCode"] == 200


def test_invalid_json():
    resp = handler({"httpMethod": "POST", "body": "not-json"}, {})
    assert resp["statusCode"] == 400
