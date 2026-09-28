import json
import os
import sys

import boto3
import pytest
from moto import mock_aws

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "src"))


@pytest.fixture
def handler(monkeypatch):
    monkeypatch.setenv("AWS_DEFAULT_REGION", "us-east-1")
    monkeypatch.setenv("AWS_ACCESS_KEY_ID", "testing")
    monkeypatch.setenv("AWS_SECRET_ACCESS_KEY", "testing")
    monkeypatch.setenv("TABLE_NAME", "links")
    with mock_aws():
        boto3.client("dynamodb").create_table(
            TableName="links",
            KeySchema=[{"AttributeName": "code", "KeyType": "HASH"}],
            AttributeDefinitions=[{"AttributeName": "code", "AttributeType": "S"}],
            BillingMode="PAY_PER_REQUEST",
        )
        import handler as h

        h._table = None
        yield h


def _post(h, body):
    return h.lambda_handler(
        {"routeKey": "POST /links", "body": json.dumps(body),
         "requestContext": {"domainName": "api.example.com"}},
        None,
    )


def test_create_and_resolve(handler):
    created = _post(handler, {"url": "https://example.com/page"})
    assert created["statusCode"] == 201
    code = json.loads(created["body"])["code"]

    resolved = handler.lambda_handler(
        {"routeKey": "GET /{code}", "pathParameters": {"code": code}}, None
    )
    assert resolved["statusCode"] == 301
    assert resolved["headers"]["location"] == "https://example.com/page"


@pytest.mark.parametrize("bad", ["", "ftp://x.com", "not a url", "javascript:alert(1)"])
def test_rejects_invalid_urls(handler, bad):
    assert _post(handler, {"url": bad})["statusCode"] == 400


def test_unknown_code_is_404(handler):
    r = handler.lambda_handler(
        {"routeKey": "GET /{code}", "pathParameters": {"code": "nope"}}, None
    )
    assert r["statusCode"] == 404
