import json
from unittest.mock import patch, MagicMock

import main

EVENT = {
    "env_id":  "abc12345",
    "team":    "payments",
    "project": "api",
}

_MOCK_CONFIG = {"url": "https://grafana.example.com", "api_key": "glsa_test"}


@patch("main._provision_dashboard", return_value="https://grafana.example.com/d/idp-abc12345")
@patch("main._get_config", return_value=_MOCK_CONFIG)
def test_happy_path(mock_cfg, mock_provision):
    result = main.handler(EVENT, {})
    assert result["dashboard_url"] == "https://grafana.example.com/d/idp-abc12345"
    mock_provision.assert_called_once()


def test_build_dashboard_structure():
    dash = main._build_dashboard("abc12345", "payments", "api")
    assert dash["uid"]    == "idp-abc12345"
    assert dash["title"]  == "IDP | payments-api-abc12345"
    assert len(dash["panels"]) == 6
    assert "payments" in dash["tags"]
    assert "abc12345" in dash["tags"]


def test_build_dashboard_panels_target_correct_namespace():
    dash = main._build_dashboard("abc12345", "payments", "api")
    for panel in dash["panels"]:
        assert "payments-api-abc12345" in panel["targets"][0]["expr"]
