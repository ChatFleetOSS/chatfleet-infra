#!/usr/bin/env python3
from __future__ import annotations

import os
import subprocess
import tempfile
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
INSTALL_SH = REPO_ROOT / "install.sh"


def resolve_pre_patch_install_dir(
    *,
    home: Path,
    install_dir: Path | None = None,
    use_system: bool = False,
) -> str:
    """Model the previous installer selector before legacy /opt detection."""

    env = {
        **os.environ,
        "HOME": str(home),
    }
    env.pop("INSTALL_DIR", None)
    env.pop("USE_SYSTEM", None)
    if install_dir is not None:
        env["INSTALL_DIR"] = str(install_dir)
    if use_system:
        env["USE_SYSTEM"] = "1"

    result = subprocess.run(
        [
            "bash",
            "-c",
            """
set -euo pipefail
if [ "${USE_SYSTEM:-0}" = "1" ]; then
  INSTALL_DIR="${INSTALL_DIR:-/opt/chatfleet-infra}"
else
  INSTALL_DIR="${INSTALL_DIR:-$HOME/chatfleet-infra}"
fi
printf "%s\\n" "$INSTALL_DIR"
""",
        ],
        check=True,
        capture_output=True,
        text=True,
        env=env,
    )
    return result.stdout.strip()


def resolve_install_dir(
    *,
    home: Path,
    system_dir: Path,
    install_dir: Path | None = None,
    use_system: bool = False,
) -> tuple[str, str]:
    env = {
        **os.environ,
        "HOME": str(home),
        "CHATFLEET_SYSTEM_INSTALL_DIR": str(system_dir),
        "CHATFLEET_INSTALLER_NO_MAIN": "1",
    }
    env.pop("INSTALL_DIR", None)
    env.pop("USE_SYSTEM", None)
    if install_dir is not None:
        env["INSTALL_DIR"] = str(install_dir)
    if use_system:
        env["USE_SYSTEM"] = "1"

    result = subprocess.run(
        [
            "bash",
            "-c",
            'source "$1"; printf "%s\\n%s\\n" "$INSTALL_DIR" "$INSTALL_DIR_SELECTED_LEGACY"',
            "bash",
            str(INSTALL_SH),
        ],
        check=True,
        capture_output=True,
        text=True,
        env=env,
    )
    install, legacy = result.stdout.strip().splitlines()
    return install, legacy


def main() -> int:
    with tempfile.TemporaryDirectory(prefix="chatfleet-install-dir-") as tmp:
        root = Path(tmp)
        home = root / "home"
        home.mkdir()
        system_dir = root / "opt" / "chatfleet-infra"
        explicit = root / "custom"

        install, legacy = resolve_install_dir(home=home, system_dir=system_dir)
        assert install == str(home / "chatfleet-infra"), install
        assert legacy == "0", legacy

        system_dir.mkdir(parents=True)
        (system_dir / ".env").write_text("JWT_SECRET=legacy\n", encoding="utf-8")
        (home / "chatfleet-infra").mkdir()

        pre_patch_install = resolve_pre_patch_install_dir(
            home=home,
        )
        assert pre_patch_install == str(home / "chatfleet-infra"), pre_patch_install

        install, legacy = resolve_install_dir(home=home, system_dir=system_dir)
        assert install == str(system_dir), install
        assert legacy == "1", legacy

        install, legacy = resolve_install_dir(
            home=home,
            system_dir=system_dir,
            install_dir=explicit,
        )
        assert install == str(explicit), install
        assert legacy == "0", legacy

        install, legacy = resolve_install_dir(
            home=home,
            system_dir=system_dir,
            use_system=True,
        )
        assert install == str(system_dir), install
        assert legacy == "0", legacy

    print("install_dir_resolution=ok")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
