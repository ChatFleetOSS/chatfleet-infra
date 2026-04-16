#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import os
import re
import sys
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path


SEMVER_RE = re.compile(r"^v\d+\.\d+\.\d+$")
REPO_ROOT = Path(__file__).resolve().parents[1]
DEFAULT_REPOS = {
    "api": "chatfleet-api",
    "web": "chatfleet-web",
}


def fetch_manifest_digest(image_name: str, tag: str) -> str:
    scope = urllib.parse.quote(f"repository:chatfleetoss/{image_name}:pull", safe="")
    token_url = f"https://ghcr.io/token?scope={scope}"
    with urllib.request.urlopen(token_url, timeout=20) as response:
        payload = json.loads(response.read().decode("utf-8"))
    token = payload["token"]

    manifest_url = f"https://ghcr.io/v2/chatfleetoss/{image_name}/manifests/{tag}"
    request = urllib.request.Request(
        manifest_url,
        headers={
            "Authorization": f"Bearer {token}",
            "Accept": ",".join(
                [
                    "application/vnd.oci.image.index.v1+json",
                    "application/vnd.docker.distribution.manifest.list.v2+json",
                    "application/vnd.oci.image.manifest.v1+json",
                    "application/vnd.docker.distribution.manifest.v2+json",
                ]
            ),
        },
        method="HEAD",
    )
    try:
        with urllib.request.urlopen(request, timeout=20) as response:
            digest = response.headers.get("docker-content-digest")
    except urllib.error.HTTPError as exc:
        raise RuntimeError(
            f"image ghcr.io/chatfleetoss/{image_name}:{tag} not found (HTTP {exc.code})"
        ) from exc
    if not digest:
        raise RuntimeError(
            f"image ghcr.io/chatfleetoss/{image_name}:{tag} did not return a digest"
        )
    return digest


def validate_tag(channel: str, tag: str, label: str, allow_non_semver: bool) -> None:
    if not tag:
        raise RuntimeError(f"{label} tag is empty")
    if channel == "stable" and not allow_non_semver and not SEMVER_RE.fullmatch(tag):
        raise RuntimeError(
            f"{label} tag '{tag}' is invalid for stable; expected a semver tag like v0.1.17"
        )


def write_channel_file(path: Path, api_tag: str, web_tag: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(f"API_TAG={api_tag}\nWEB_TAG={web_tag}\n", encoding="utf-8")


def read_channel_file(path: Path) -> tuple[str | None, str | None]:
    if not path.exists():
        return None, None
    api_tag = None
    web_tag = None
    for raw_line in path.read_text(encoding="utf-8").splitlines():
        line = raw_line.strip()
        if line.startswith("API_TAG="):
            api_tag = line.split("=", 1)[1]
        elif line.startswith("WEB_TAG="):
            web_tag = line.split("=", 1)[1]
    return api_tag, web_tag


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Promote or validate a ChatFleet channel")
    parser.add_argument("--channel", default="stable")
    parser.add_argument("--api-tag", required=True)
    parser.add_argument("--web-tag", required=True)
    parser.add_argument(
        "--channel-file",
        help="Override the target channel file path. Defaults to channels/<channel>.env",
    )
    parser.add_argument(
        "--verify-only",
        action="store_true",
        help="Validate the tags without writing the channel file",
    )
    parser.add_argument(
        "--skip-registry-check",
        action="store_true",
        help="Skip GHCR manifest checks",
    )
    parser.add_argument(
        "--allow-non-semver",
        action="store_true",
        help="Allow non-semver tags in stable (useful only for local simulation)",
    )
    return parser


def main() -> int:
    parser = build_parser()
    args = parser.parse_args()

    channel_file = (
        Path(args.channel_file)
        if args.channel_file
        else REPO_ROOT / "channels" / f"{args.channel}.env"
    )

    validate_tag(args.channel, args.api_tag, "API", args.allow_non_semver)
    validate_tag(args.channel, args.web_tag, "Web", args.allow_non_semver)

    api_digest = None
    web_digest = None
    if not args.skip_registry_check:
        api_digest = fetch_manifest_digest(DEFAULT_REPOS["api"], args.api_tag)
        web_digest = fetch_manifest_digest(DEFAULT_REPOS["web"], args.web_tag)

    current_api, current_web = read_channel_file(channel_file)
    print(f"channel={args.channel}")
    print(f"channel_file={channel_file}")
    print(f"current_api_tag={current_api or ''}")
    print(f"current_web_tag={current_web or ''}")
    print(f"next_api_tag={args.api_tag}")
    print(f"next_web_tag={args.web_tag}")
    if api_digest:
        print(f"api_digest={api_digest}")
    if web_digest:
        print(f"web_digest={web_digest}")

    if not args.verify_only:
        write_channel_file(channel_file, args.api_tag, args.web_tag)
        print("updated=true")
    else:
        print("updated=false")

    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as exc:
        print(f"[chatfleet-promote][error] {exc}", file=sys.stderr)
        raise SystemExit(1)
