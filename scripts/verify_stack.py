#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import sys
import urllib.error
import urllib.request


def fetch_json(url: str, timeout: float) -> dict:
    try:
        with urllib.request.urlopen(url, timeout=timeout) as response:
            if response.status != 200:
                raise RuntimeError(f"{url} returned HTTP {response.status}")
            return json.loads(response.read().decode("utf-8"))
    except urllib.error.URLError as exc:
        raise RuntimeError(f"request failed for {url}: {exc}") from exc


def main() -> int:
    parser = argparse.ArgumentParser(description="Verify ChatFleet stack versions")
    parser.add_argument("--base-url", default="http://localhost:8080")
    parser.add_argument("--expected-api")
    parser.add_argument("--expected-web")
    parser.add_argument("--timeout", type=float, default=10.0)
    args = parser.parse_args()

    base_url = args.base_url.rstrip("/")
    health = fetch_json(f"{base_url}/api/health", args.timeout)

    api_version = ((health.get("build") or {}).get("version")) if isinstance(health, dict) else None
    status = health.get("status") if isinstance(health, dict) else None
    web_version = None

    if args.expected_web:
        build_info = fetch_json(f"{base_url}/build-info", args.timeout)
        web_version = ((build_info.get("build") or {}).get("version")) if isinstance(build_info, dict) else None

    print(f"health.status={status}")
    print(f"health.build.version={api_version}")
    if args.expected_web:
        print(f"build-info.build.version={web_version}")

    if status != "ok":
        raise RuntimeError(f"unexpected health status: {status!r}")
    if args.expected_api and api_version != args.expected_api:
        raise RuntimeError(
            f"api version mismatch: expected {args.expected_api}, got {api_version}"
        )
    if args.expected_web and web_version != args.expected_web:
        raise RuntimeError(
            f"web version mismatch: expected {args.expected_web}, got {web_version}"
        )
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as exc:  # pragma: no cover - used by CI and operators
        print(f"[chatfleet-verify][error] {exc}", file=sys.stderr)
        raise SystemExit(1)
