#!/usr/bin/env bash
set -euo pipefail
DIR="${1:-/opt/chatfleet-infra}"
API_TAG="${API_TAG:-latest}"
WEB_TAG="${WEB_TAG:-latest}"
cd "$DIR"
echo "[chatfleet-upgrade] Pulling updates to repo..."
git pull --ff-only || true
echo "[chatfleet-upgrade] Using tags: api=$API_TAG web=$WEB_TAG"
export API_TAG WEB_TAG
docker compose pull
docker compose up -d
echo "[chatfleet-upgrade] Done."
