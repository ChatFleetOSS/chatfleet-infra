#!/usr/bin/env python3
from __future__ import annotations

import os
import subprocess
import tempfile
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
INSTALL_SH = REPO_ROOT / "install.sh"


def repair_env(
    initial_env: str,
    password: str | None = "abc+123",
    force_repair: bool = False,
) -> str:
    with tempfile.TemporaryDirectory(prefix="chatfleet-mongo-uri-") as tmp:
        install_dir = Path(tmp)
        (install_dir / ".env").write_text(initial_env, encoding="utf-8")
        env = {
            **os.environ,
            "INSTALL_DIR": str(install_dir),
            "CHATFLEET_INSTALLER_NO_MAIN": "1",
            "REPAIR_MONGO_URI": "1" if force_repair else "0",
        }
        if password is not None:
            env["MONGO_APP_PASSWORD"] = password
        subprocess.run(
            [
                "bash",
                "-c",
                'source "$1"; repair_mongo_uri_if_needed',
                "bash",
                str(INSTALL_SH),
            ],
            check=True,
            capture_output=True,
            text=True,
            env=env,
        )
        return (install_dir / ".env").read_text(encoding="utf-8")


def env_value(content: str, key: str) -> str:
    for line in content.splitlines():
        if line.startswith(f"{key}="):
            return line.split("=", 1)[1]
    raise AssertionError(f"{key} not found in env content: {content!r}")


def main() -> int:
    target = "mongodb://chatfleet:abc%2B123@mongo:27017/chatfleet?authSource=chatfleet"

    repaired = repair_env("JWT_SECRET=x\nMONGO_APP_PASSWORD=abc+123\n")
    assert env_value(repaired, "MONGO_URI") == target

    repaired = repair_env("MONGO_APP_PASSWORD=abc+123\nMONGO_URI=\n")
    assert env_value(repaired, "MONGO_URI") == target

    legacy_uri = "mongodb://chatfleet:abc+123@mongo:27017/chatfleet?authSource=admin"
    repaired = repair_env(
        "MONGO_APP_PASSWORD=abc+123\n"
        f"MONGO_URI={legacy_uri}\n"
    )
    assert env_value(repaired, "MONGO_URI") == legacy_uri

    repaired = repair_env(
        "MONGO_APP_PASSWORD=abc+123\n"
        f"MONGO_URI={legacy_uri}\n",
        force_repair=True,
    )
    assert env_value(repaired, "MONGO_URI") == target

    custom_uri = "mongodb://chatfleet:abc+123@db.example:27017/chatfleet?authSource=admin"
    repaired = repair_env(f"MONGO_APP_PASSWORD=abc+123\nMONGO_URI={custom_uri}\n")
    assert env_value(repaired, "MONGO_URI") == custom_uri

    existing_uri = "mongodb://legacy-user:legacy-pass@mongo:27017/chatfleet?authSource=admin"
    repaired = repair_env(f"MONGO_URI={existing_uri}\n", password=None)
    assert env_value(repaired, "MONGO_URI") == existing_uri

    print("mongo_uri_repair=ok")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
