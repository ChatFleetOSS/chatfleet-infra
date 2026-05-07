#!/usr/bin/env bash
set -euo pipefail

SYSTEM_INSTALL_DIR="${CHATFLEET_SYSTEM_INSTALL_DIR:-/opt/chatfleet-infra}"
HOME_INSTALL_DIR="${CHATFLEET_HOME_INSTALL_DIR:-$HOME/chatfleet-infra}"
DEFAULT_DIR="$HOME_INSTALL_DIR"
DEFAULT_DIR_SELECTED_LEGACY=0
if [ -f "$SYSTEM_INSTALL_DIR/.env" ] || [ -d "$SYSTEM_INSTALL_DIR/.git" ]; then
  DEFAULT_DIR="$SYSTEM_INSTALL_DIR"
  DEFAULT_DIR_SELECTED_LEGACY=1
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

verify_stack_versions() {
  local args=("--base-url" "http://localhost:8080")

  if [ "$API_TAG" = "edge" ]; then
    args+=("--expected-api-prefix" "sha-")
  else
    args+=("--expected-api" "$API_TAG")
  fi

  if [ "$WEB_TAG" = "edge" ]; then
    args+=("--expected-web-prefix" "sha-")
  else
    args+=("--expected-web" "$WEB_TAG")
  fi

  python3 "$DIR/scripts/verify_stack.py" "${args[@]}"
}

[ -d "$DIR" ] || die "Install directory not found: $DIR"

if [ "$DEFAULT_DIR_SELECTED_LEGACY" = "1" ] && [ -z "${1:-}" ] && [ -z "${INSTALL_DIR:-}" ]; then
  log "Detected an existing system install at $DIR; reusing it to preserve .env secrets and Docker volumes. Pass a path or set INSTALL_DIR to override."
fi

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
verify_stack_versions
log "Done."
