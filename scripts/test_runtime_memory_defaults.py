#!/usr/bin/env python3
from __future__ import annotations

from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
COMPOSE = REPO_ROOT / "docker-compose.yml"
ENV_EXAMPLE = REPO_ROOT / ".env.example"


EXPECTED_DEFAULTS = {
    "CHATFLEET_API_WORKERS": "1",
    "CHATFLEET_EMBED_CONCURRENCY": "1",
    "CHATFLEET_AUTO_SUGGESTIONS": "1",
    "TOKENIZERS_PARALLELISM": "false",
    "OMP_NUM_THREADS": "1",
    "OPENBLAS_NUM_THREADS": "1",
    "MKL_NUM_THREADS": "1",
}


def main() -> int:
    compose = COMPOSE.read_text(encoding="utf-8")
    env_example = ENV_EXAMPLE.read_text(encoding="utf-8")

    for key, default in EXPECTED_DEFAULTS.items():
        assert f"{key}: ${{{key}:-{default}}}" in compose, (
            f"{key} must have compose default {default}"
        )
        assert f"{key}={default}" in env_example, (
            f"{key} must be documented in .env.example"
        )

    print("runtime_memory_defaults=ok")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
