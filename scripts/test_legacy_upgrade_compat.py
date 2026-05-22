#!/usr/bin/env python3
from __future__ import annotations

import os
import subprocess
import tempfile
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
INSTALL_SH = REPO_ROOT / "install.sh"


LEGACY_URI = "mongodb://legacy-user:legacy-pass@mongo:27017/chatfleet?authSource=admin"
LEGACY_ENV = "\n".join(
    [
        "JWT_SECRET=legacy-jwt-secret-12345678901234567890",
        "MONGO_ROOT_USER=root",
        "MONGO_ROOT_PASSWORD=legacy-root-password",
        f"MONGO_URI={LEGACY_URI}",
        "API_TAG=v0.1.16",
        "WEB_TAG=v0.1.18",
        "",
    ]
)


def _source_install(system_dir: Path, home: Path, extra: str = "") -> str:
    env = {
        **os.environ,
        "HOME": str(home),
        "CHATFLEET_SYSTEM_INSTALL_DIR": str(system_dir),
        "CHATFLEET_INSTALLER_NO_MAIN": "1",
    }
    env.pop("INSTALL_DIR", None)
    env.pop("USE_SYSTEM", None)
    proc = subprocess.run(
        [
            "bash",
            "-c",
            (
                'source "$1"; '
                'printf "INSTALL_DIR=%s\\nLEGACY=%s\\n" "$INSTALL_DIR" "$INSTALL_DIR_SELECTED_LEGACY"; '
                f"{extra}"
            ),
            "bash",
            str(INSTALL_SH),
        ],
        check=True,
        capture_output=True,
        text=True,
        env=env,
    )
    return proc.stdout


def _env_value(content: str, key: str) -> str:
    for line in content.splitlines():
        if line.startswith(f"{key}="):
            return line.split("=", 1)[1]
    raise AssertionError(f"{key} missing from env")


def main() -> int:
    with tempfile.TemporaryDirectory(prefix="chatfleet-legacy-upgrade-") as tmp:
        root = Path(tmp)
        home = root / "home"
        system_dir = root / "opt" / "chatfleet-infra"
        home_install = home / "chatfleet-infra"
        home.mkdir()
        system_dir.mkdir(parents=True)
        home_install.mkdir(parents=True)
        env_file = system_dir / ".env"
        env_file.write_text(LEGACY_ENV, encoding="utf-8")

        output = _source_install(system_dir, home)
        assert f"INSTALL_DIR={system_dir}" in output, output
        assert "LEGACY=1" in output, output

        output = _source_install(system_dir, home, "repair_mongo_uri_if_needed")
        assert "INSTALL_DIR=" in output
        preserved = env_file.read_text(encoding="utf-8")
        assert _env_value(preserved, "MONGO_URI") == LEGACY_URI
        assert _env_value(preserved, "JWT_SECRET") == "legacy-jwt-secret-12345678901234567890"
        assert _env_value(preserved, "MONGO_ROOT_PASSWORD") == "legacy-root-password"
        assert "MONGO_APP_PASSWORD=" not in preserved

    print("legacy_upgrade_compat=ok")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
