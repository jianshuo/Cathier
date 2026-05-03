#!/usr/bin/env python3
"""Minimal Azure OpenAI chat completions connectivity test.

Required env:
  AZURE_OPENAI_API_KEY

Optional env:
  AZURE_OPENAI_ENDPOINT      default: https://openai-gtp4-baixing.openai.azure.com/
  AZURE_OPENAI_API_VERSION   default: 2024-05-01-preview
  AZURE_OPENAI_DEPLOYMENT    or pass --deployment
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
DEFAULT_API_VERSION = "2024-05-01-preview"


def build_url(endpoint: str, deployment: str, api_version: str) -> str:
    endpoint = endpoint.rstrip("/")
    deployment_path = urllib.parse.quote(deployment, safe="")
    return (
        f"{endpoint}/openai/deployments/{deployment_path}/chat/completions"
        f"?api-version={urllib.parse.quote(api_version, safe='')}"
    )


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Test an Azure OpenAI chat completions deployment."
    )
    parser.add_argument(
        "--endpoint",
        default=os.getenv("AZURE_OPENAI_ENDPOINT", DEFAULT_ENDPOINT),
        help=f"Azure OpenAI endpoint. Default: {DEFAULT_ENDPOINT}",
    )
    parser.add_argument(
        "--api-version",
        default=os.getenv("AZURE_OPENAI_API_VERSION", DEFAULT_API_VERSION),
        help=f"Azure OpenAI API version. Default: {DEFAULT_API_VERSION}",
    )
    parser.add_argument(
        "--deployment",
        default=os.getenv("AZURE_OPENAI_DEPLOYMENT"),
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

    if not args.deployment:
        print(
            "Missing deployment. Set AZURE_OPENAI_DEPLOYMENT or pass --deployment.",
            file=sys.stderr,
        )
        return 2

    url = build_url(args.endpoint, args.deployment, args.api_version)
    payload = {
        "messages": [
            {"role": "system", "content": "You are a concise test assistant."},
            {"role": "user", "content": args.message},
        ],
        "temperature": 0,
        "max_tokens": 40,
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

    print(f"Endpoint:   {args.endpoint.rstrip('/')}")
    print(f"API version:{args.api_version}")
    print(f"Deployment: {args.deployment}")

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
