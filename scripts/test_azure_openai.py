#!/usr/bin/env python3
"""Minimal Azure OpenAI chat completions connectivity test.

Required env:
  AZURE_OPENAI_API_KEY

Optional env:
  AZURE_OPENAI_URL           full chat completions URL
  AZURE_OPENAI_ENDPOINT      Azure resource endpoint
  AZURE_OPENAI_API_VERSION   default: 2025-01-01-preview
  AZURE_OPENAI_DEPLOYMENT    default: gpt-5
"""

from __future__ import annotations

import argparse
import json
import os
import sys
import urllib.error
import urllib.parse
import urllib.request


DEFAULT_ENDPOINT = "https://openai-gtp4-baixing.openai.azure.com/"
DEFAULT_DEPLOYMENT = "gpt-5"
DEFAULT_API_VERSION = "2025-01-01-preview"
DEFAULT_URL = (
    "https://openai-gtp4-baixing.openai.azure.com/openai/deployments/"
    "gpt-5/chat/completions?api-version=2025-01-01-preview"
)


def build_url(endpoint: str, deployment: str, api_version: str) -> str:
    endpoint = endpoint.rstrip("/")
    deployment_path = urllib.parse.quote(deployment, safe="")
    return (
        f"{endpoint}/openai/deployments/{deployment_path}/chat/completions"
        f"?api-version={urllib.parse.quote(api_version, safe='')}"
    )


def with_api_version(url: str, api_version: str) -> str:
    parts = urllib.parse.urlsplit(url)
    query = dict(urllib.parse.parse_qsl(parts.query, keep_blank_values=True))
    query["api-version"] = api_version
    return urllib.parse.urlunsplit(
        parts._replace(query=urllib.parse.urlencode(query))
    )


def deployment_from_url(url: str) -> str | None:
    path_parts = urllib.parse.urlsplit(url).path.strip("/").split("/")
    try:
        deployments_index = path_parts.index("deployments")
    except ValueError:
        return None

    if deployments_index + 1 >= len(path_parts):
        return None
    return urllib.parse.unquote(path_parts[deployments_index + 1])


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Test an Azure OpenAI chat completions deployment."
    )
    parser.add_argument(
        "--url",
        default=os.getenv("AZURE_OPENAI_URL", DEFAULT_URL),
        help="Full Azure OpenAI chat completions URL.",
    )
    parser.add_argument(
        "--endpoint",
        default=os.getenv("AZURE_OPENAI_ENDPOINT"),
        help=f"Azure OpenAI endpoint. Default: {DEFAULT_ENDPOINT}",
    )
    parser.add_argument(
        "--api-version",
        default=os.getenv("AZURE_OPENAI_API_VERSION", DEFAULT_API_VERSION),
        help=f"Azure OpenAI API version. Default: {DEFAULT_API_VERSION}",
    )
    parser.add_argument(
        "--deployment",
        default=os.getenv("AZURE_OPENAI_DEPLOYMENT", DEFAULT_DEPLOYMENT),
        help="Azure deployment name, not the model name unless you named it that way.",
    )
    parser.add_argument(
        "--message",
        default="Say pong in one short sentence.",
        help="User message to send.",
    )
    args = parser.parse_args()

    api_key = os.getenv("AZURE_OPENAI_API_KEY")
    if not api_key:
        print("Missing env: AZURE_OPENAI_API_KEY", file=sys.stderr)
        return 2

    if args.endpoint:
        url = build_url(args.endpoint, args.deployment, args.api_version)
        endpoint_for_print = args.endpoint.rstrip("/")
        deployment_for_print = args.deployment
    else:
        url = with_api_version(args.url, args.api_version)
        split_url = urllib.parse.urlsplit(url)
        endpoint_for_print = f"{split_url.scheme}://{split_url.netloc}"
        deployment_for_print = deployment_from_url(url) or args.deployment

    payload = {
        "messages": [
            {"role": "system", "content": "You are a concise test assistant."},
            {"role": "user", "content": args.message},
        ],
        "max_completion_tokens": 1024,
    }

    request = urllib.request.Request(
        url,
        data=json.dumps(payload).encode("utf-8"),
        headers={
            "Content-Type": "application/json",
            "api-key": api_key,
        },
        method="POST",
    )

    print(f"Endpoint:   {endpoint_for_print}")
    print(f"API version:{args.api_version}")
    print(f"Deployment: {deployment_for_print}")

    try:
        with urllib.request.urlopen(request, timeout=30) as response:
            body = json.loads(response.read().decode("utf-8"))
    except urllib.error.HTTPError as exc:
        error_body = exc.read().decode("utf-8", errors="replace")
        print(f"\nHTTP {exc.code} from Azure OpenAI", file=sys.stderr)
        print(error_body, file=sys.stderr)
        return 1
    except urllib.error.URLError as exc:
        print(f"\nNetwork error: {exc.reason}", file=sys.stderr)
        return 1

    content = (
        body.get("choices", [{}])[0]
        .get("message", {})
        .get("content", "")
        .strip()
    )
    if not content:
        print("\nRequest succeeded but response content was empty.")
        print(json.dumps(body, ensure_ascii=False, indent=2))
        return 1

    print("\nOK. Response:")
    print(content)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
