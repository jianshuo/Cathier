"""Thin wrapper around OpenAI Images API (gpt-image-1).

Returns the saved file path; lets callers handle errors via exception.
"""

import base64
from pathlib import Path

import httpx
from openai import OpenAI

MODEL = "gpt-image-1"


def generate_image(
    prompt: str,
    size: str,
    output_path: Path,
    api_key: str,
) -> Path:
    if not prompt:
        raise ValueError("prompt must be non-empty")

    client = OpenAI(api_key=api_key, http_client=httpx.Client())
    response = client.images.generate(
        model=MODEL,
        prompt=prompt,
        size=size,
        n=1,
    )
    b64 = response.data[0].b64_json
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_bytes(base64.b64decode(b64))
    return output_path
