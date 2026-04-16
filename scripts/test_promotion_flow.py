#!/usr/bin/env python3
from __future__ import annotations

import argparse
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path


SEMVER_RE = re.compile(r"^v(\d+)\.(\d+)\.(\d+)$")
REPO_ROOT = Path(__file__).resolve().parents[1]
PROMOTE_SCRIPT = REPO_ROOT / "scripts" / "promote_channel.py"


def sort_key(tag: str) -> tuple[int, int, int]:
    match = SEMVER_RE.fullmatch(tag)
    if not match:
        raise RuntimeError(f"invalid semver tag: {tag}")
    return tuple(int(part) for part in match.groups())


def latest_tags(repo_url: str, count: int) -> list[str]:
    result = subprocess.run(
        ["git", "ls-remote", "--tags", "--refs", repo_url],
        check=True,
        capture_output=True,
        text=True,
    )
    tags = []
    for line in result.stdout.splitlines():
        ref = line.split("\t", 1)[1]
        tag = ref.rsplit("/", 1)[-1]
        if SEMVER_RE.fullmatch(tag):
            tags.append(tag)
    tags.sort(key=sort_key)
    if len(tags) < count:
        raise RuntimeError(f"{repo_url} has only {len(tags)} semver tags")
    return tags[-count:]


def parse_channel_file(path: Path) -> tuple[str, str]:
    api_tag = None
    web_tag = None
    for raw_line in path.read_text(encoding="utf-8").splitlines():
        line = raw_line.strip()
        if line.startswith("API_TAG="):
            api_tag = line.split("=", 1)[1]
        elif line.startswith("WEB_TAG="):
            web_tag = line.split("=", 1)[1]
    if not api_tag or not web_tag:
        raise RuntimeError(f"invalid channel file {path}")
    return api_tag, web_tag


def run_promotion(channel_file: Path, api_tag: str, web_tag: str, skip_registry_check: bool) -> None:
    cmd = [
        sys.executable,
        str(PROMOTE_SCRIPT),
        "--channel",
        "stable",
        "--channel-file",
        str(channel_file),
        "--api-tag",
        api_tag,
        "--web-tag",
        web_tag,
    ]
    if skip_registry_check:
        cmd.append("--skip-registry-check")
    subprocess.run(cmd, check=True)
    current_api, current_web = parse_channel_file(channel_file)
    if current_api != api_tag or current_web != web_tag:
        raise RuntimeError(
            f"promotion mismatch: expected {api_tag}/{web_tag}, got {current_api}/{current_web}"
        )


def main() -> int:
    parser = argparse.ArgumentParser(description="Exercise stable promotions over three successive versions")
    parser.add_argument(
        "--skip-registry-check",
        action="store_true",
        help="Skip GHCR checks while testing the promotion script",
    )
    args = parser.parse_args()

    api_tags = latest_tags("https://github.com/ChatFleetOSS/chatfleet-api.git", 3)
    web_tags = latest_tags("https://github.com/ChatFleetOSS/chatfleet-web.git", 3)

    with tempfile.TemporaryDirectory(prefix="chatfleet-promotion-") as tmpdir:
        tmp_path = Path(tmpdir)
        channel_file = tmp_path / "stable.env"
        source_file = REPO_ROOT / "channels" / "stable.env"
        shutil.copyfile(source_file, channel_file)

        print(f"Testing promotion flow with {list(zip(api_tags, web_tags))}")
        for api_tag, web_tag in zip(api_tags, web_tags):
            run_promotion(channel_file, api_tag, web_tag, args.skip_registry_check)

    print("promotion_flow=ok")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
