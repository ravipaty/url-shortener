"""URL shortener Lambda (API Gateway HTTP API, payload v2.0).

POST /links   {"url": "https://..."}  -> 201 {"code": "...", "short_url": "..."}
GET  /{code}                          -> 301 redirect to the original URL
"""
import json
import os
import secrets
import time
from urllib.parse import urlparse

import boto3
from botocore.exceptions import ClientError

_table = None


def _get_table():
    # Created lazily so tests can mock AWS before first use
    global _table
    if _table is None:
        _table = boto3.resource("dynamodb").Table(os.environ["TABLE_NAME"])
    return _table


def _response(status, body=None, headers=None):
    return {
        "statusCode": status,
        "headers": {"content-type": "application/json", **(headers or {})},
        "body": json.dumps(body) if body is not None else "",
    }


def _is_valid_url(url):
    try:
        parsed = urlparse(url)
    except (TypeError, ValueError):
        return False
    return parsed.scheme in ("http", "https") and bool(parsed.netloc) and len(url) <= 2048


def create_link(event):
    try:
        payload = json.loads(event.get("body") or "{}")
    except json.JSONDecodeError:
        return _response(400, {"error": "Body must be JSON"})

    url = payload.get("url", "")
    if not _is_valid_url(url):
        return _response(400, {"error": "Provide a valid http(s) URL"})

    for _ in range(5):  # retry on the (rare) code collision
        code = secrets.token_urlsafe(6)[:7]
        try:
            _get_table().put_item(
                Item={"code": code, "url": url, "created_at": int(time.time())},
                ConditionExpression="attribute_not_exists(code)",
            )
        except ClientError as err:
            if err.response["Error"]["Code"] == "ConditionalCheckFailedException":
                continue
            raise
        domain = event.get("requestContext", {}).get("domainName", "")
        return _response(201, {"code": code, "short_url": f"https://{domain}/{code}"})

    return _response(500, {"error": "Could not allocate a short code"})


def resolve_link(event):
    code = (event.get("pathParameters") or {}).get("code", "")
    item = _get_table().get_item(Key={"code": code}).get("Item")
    if not item:
        return _response(404, {"error": "Not found"})
    return _response(301, headers={"location": item["url"]})


def lambda_handler(event, context):
    route = event.get("routeKey", "")
    if route == "POST /links":
        return create_link(event)
    if route == "GET /{code}":
        return resolve_link(event)
    return _response(404, {"error": "Unknown route"})
