#!/usr/bin/env bash
set -euo pipefail
DIR="${1:-/opt/chatfleet-infra}"
PURGE="${PURGE:-0}"
cd "$DIR"
echo "[chatfleet-uninstall] Stopping services..."
docker compose down
if [ "$PURGE" = "1" ]; then
  echo "[chatfleet-uninstall] Removing volumes (mongo data, index, uploads)..."
  docker volume rm chatfleet_mongo_data chatfleet_chatfleet_index chatfleet_chatfleet_uploads || true
fi
echo "[chatfleet-uninstall] Done."
