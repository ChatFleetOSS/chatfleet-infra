#!/usr/bin/env bash
set -euo pipefail

DEFAULT_DIR="$HOME/chatfleet-infra"
if [ ! -d "$DEFAULT_DIR" ] && [ -d /opt/chatfleet-infra ]; then
  DEFAULT_DIR="/opt/chatfleet-infra"
fi

DIR="${1:-${INSTALL_DIR:-$DEFAULT_DIR}}"

log() { echo "[chatfleet-upgrade] $*"; }
die() { echo "[chatfleet-upgrade][error] $*" >&2; exit 1; }

read_env_value() {
  local key="$1"
  [ -f .env ] || return 0
  sed -n "s/^${key}=\(.*\)$/\1/p" .env | tail -n1
}

upsert_env_value() {
  local key="$1"
  local value="$2"
  if grep -q "^${key}=" .env 2>/dev/null; then
    sed -i.bak "s|^${key}=.*$|${key}=${value}|" .env || true
  else
    printf '%s=%s\n' "$key" "$value" >> .env
  fi
  rm -f .env.bak || true
}

[ -d "$DIR" ] || die "Install directory not found: $DIR"

cd "$DIR"
if [ -d .git ]; then
  log "Pulling infra repo updates..."
  git pull --ff-only || true
fi

STORED_CHANNEL="$(read_env_value CHATFLEET_CHANNEL)"
eval "$(
  EDGE="${EDGE:-0}" \
  CHANNEL="${CHANNEL:-${STORED_CHANNEL:-}}" \
  CHATFLEET_CHANNEL="${STORED_CHANNEL:-}" \
  API_TAG="${API_TAG:-}" \
  WEB_TAG="${WEB_TAG:-}" \
  bash "$DIR/scripts/resolve-channel.sh"
)"

upsert_env_value CHATFLEET_CHANNEL "$CHATFLEET_CHANNEL"
upsert_env_value API_TAG "$API_TAG"
upsert_env_value WEB_TAG "$WEB_TAG"

log "Deploying channel=${CHATFLEET_CHANNEL} api=${API_TAG} web=${WEB_TAG}"
docker compose pull
docker compose up -d --remove-orphans
python3 "$DIR/scripts/verify_stack.py" \
  --base-url "http://localhost:8080" \
  --expected-api "$API_TAG" \
  --expected-web "$WEB_TAG"
log "Done."
