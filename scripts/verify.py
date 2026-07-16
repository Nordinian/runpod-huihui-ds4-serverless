#!/usr/bin/env python3
import argparse
import json
import os
import time
import urllib.error
import urllib.request


def request(url, api_key, path, payload=None, timeout=1800):
    body = None if payload is None else json.dumps(payload).encode("utf-8")
    headers = {"Authorization": f"Bearer {api_key}"}
    if body is not None:
        headers["Content-Type"] = "application/json"
    req = urllib.request.Request(
        f"{url.rstrip('/')}{path}",
        data=body,
        headers=headers,
        method="GET" if body is None else "POST",
    )
    started = time.monotonic()
    try:
        with urllib.request.urlopen(req, timeout=timeout) as response:
            data = response.read().decode("utf-8")
            return response.status, time.monotonic() - started, data
    except urllib.error.HTTPError as error:
        data = error.read().decode("utf-8", errors="replace")
        return error.code, time.monotonic() - started, data


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--base-url", required=True)
    parser.add_argument("--api-key", default=os.environ.get("RUNPOD_API_KEY"))
    args = parser.parse_args()

    if not args.api_key:
        parser.error("--api-key or RUNPOD_API_KEY is required")

    checks = [
        ("/v1/models", None),
        (
            "/v1/chat/completions",
            {
                "model": "deepseek-v4-flash",
                "messages": [{"role": "user", "content": "Reply with exactly: OK"}],
                "max_tokens": 16,
                "temperature": 0,
                "stream": False,
            },
        ),
        (
            "/v1/responses",
            {
                "model": "deepseek-v4-flash",
                "input": "Reply with exactly: OK",
                "max_output_tokens": 16,
                "stream": False,
            },
        ),
        (
            "/v1/messages",
            {
                "model": "deepseek-v4-flash",
                "max_tokens": 16,
                "messages": [{"role": "user", "content": "Reply with exactly: OK"}],
                "stream": False,
            },
        ),
    ]

    failed = False
    for path, payload in checks:
        status, elapsed, body = request(
            args.base_url, args.api_key, path, payload=payload
        )
        print(f"{path}: HTTP {status}, {elapsed:.2f}s")
        print(body[:2000])
        if status != 200:
            failed = True

    raise SystemExit(1 if failed else 0)


if __name__ == "__main__":
    main()

