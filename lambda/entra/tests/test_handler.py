import json
from unittest.mock import MagicMock, patch
import urllib.error

import pytest
import main


EVENT = {
    "env_id":      "abc12345",
    "team":        "payments",
    "project":     "api",
    "owner_email": "dev@example.com",
}


def _mock_creds():
    return {"tenant_id": "t", "client_id": "c", "client_secret": "s"}


@patch("main._get_user_id", return_value="user-uuid")
@patch("main._assign_owner")
@patch("main._create_group", return_value="group-uuid")
@patch("main._get_token", return_value="fake-token")
@patch("main._get_credentials", return_value=_mock_creds())
def test_happy_path(mock_creds, mock_token, mock_create, mock_assign, mock_user):
    result = main.handler(EVENT, {})

    assert result["group_id"]   == "group-uuid"
    assert result["group_name"] == "idp-payments-api-abc12345"
    mock_create.assert_called_once_with("fake-token", "idp-payments-api-abc12345", "payments", "api")
    mock_assign.assert_called_once_with("fake-token", "group-uuid", "dev@example.com")


@patch("main._get_user_id", return_value=None)
@patch("main._assign_owner")
@patch("main._create_group", return_value="group-uuid")
@patch("main._get_token", return_value="fake-token")
@patch("main._get_credentials", return_value=_mock_creds())
def test_owner_not_found_still_succeeds(mock_creds, mock_token, mock_create, mock_assign, mock_user):
    result = main.handler(EVENT, {})
    assert result["group_id"] == "group-uuid"
