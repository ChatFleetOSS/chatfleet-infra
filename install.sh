#!/usr/bin/env bash
set -euo pipefail

# Install location
# Default to user home for least-privilege installs; set USE_SYSTEM=1 to opt into /opt
if [ "${USE_SYSTEM:-0}" = "1" ]; then
  INSTALL_DIR="${INSTALL_DIR:-/opt/chatfleet-infra}"
else
  INSTALL_DIR="${INSTALL_DIR:-$HOME/chatfleet-infra}"
fi
API_TAG_DEFAULT="${API_TAG:-latest}"
WEB_TAG_DEFAULT="${WEB_TAG:-latest}"
INSTALL_DOCKER="${INSTALL_DOCKER:-0}"

log() { echo -e "[chatfleet-install] $*"; }
die() { echo -e "[chatfleet-install][error] $*" >&2; exit 1; }

need_cmd() { command -v "$1" >/dev/null 2>&1 || die "Required command '$1' not found"; }

gen_secret() {
  if command -v openssl >/dev/null 2>&1; then
    openssl rand -base64 48 | tr -d '\n'
  else
    head -c 48 /dev/urandom | base64 | tr -d '\n'
  fi
}

install_docker_if_needed() {
  if command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1; then
    return
  fi
  if [ "$INSTALL_DOCKER" != "1" ]; then
    if [ "$(uname -s)" = "Darwin" ]; then
      log "Docker Desktop not found. Attempting to open Docker if installed..."
      if command -v open >/dev/null 2>&1; then open -a Docker || true; fi
      die "Please install and start Docker Desktop, or re-run with INSTALL_DOCKER=1 on Linux."
    fi
    die "Docker/Compose not found. Re-run with INSTALL_DOCKER=1 to auto-install (Debian/Ubuntu), or install Docker manually."
  fi
  if [ -f /etc/debian_version ]; then
    log "Installing Docker/Compose via convenience script..."
    if ! command -v sudo >/dev/null 2>&1; then die "sudo required to install Docker"; fi
    curl -fsSL https://get.docker.com | sudo sh
    sudo usermod -aG docker "$USER" 2>/dev/null || true
  else
    die "Auto-install supported only on Debian/Ubuntu. Please install Docker manually."
  fi
}

ensure_repo() {
  if [ -d "$INSTALL_DIR/.git" ]; then
    log "Updating existing repo at $INSTALL_DIR"
    git -C "$INSTALL_DIR" pull --ff-only || true
  else
    log "Cloning ChatFleetOSS/chatfleet-infra into $INSTALL_DIR"
    if ! mkdir -p "$INSTALL_DIR" 2>/dev/null; then
      log "Cannot write to $INSTALL_DIR. Attempting to use elevated permissions..."
      if command -v sudo >/dev/null 2>&1; then
        sudo mkdir -p "$INSTALL_DIR"
        # Determine a reasonable group
        GROUP_NAME=$(id -gn "$USER" 2>/dev/null || echo "staff")
        sudo chown -R "$USER":"$GROUP_NAME" "$INSTALL_DIR"
      else
        die "sudo not available; cannot create $INSTALL_DIR. Try: INSTALL_DIR=\"$HOME/chatfleet-infra\" bash -c '<installer>'"
      fi
    fi
    git clone https://github.com/ChatFleetOSS/chatfleet-infra "$INSTALL_DIR"
  fi
}

ensure_env() {
  cd "$INSTALL_DIR"
  if [ ! -f .env ]; then
    log "Generating .env with secure defaults"
    cp .env.example .env
    JWT_SECRET=$(gen_secret)
    MONGO_ROOT_USER="root"
    MONGO_ROOT_PASSWORD=$(gen_secret)
    # Generate an app password that is URL-safe (hex)
    if command -v openssl >/dev/null 2>&1; then
      MONGO_APP_PASSWORD=$(openssl rand -hex 24 | tr -d '\n')
    else
      MONGO_APP_PASSWORD=$(head -c 24 /dev/urandom | od -An -tx1 | tr -d ' \n')
    fi
    sed -i.bak "s|^JWT_SECRET=.*$|JWT_SECRET=${JWT_SECRET}|" .env || true
    sed -i.bak "s|^MONGO_ROOT_USER=.*$|MONGO_ROOT_USER=${MONGO_ROOT_USER}|" .env || true
    sed -i.bak "s|^MONGO_ROOT_PASSWORD=.*$|MONGO_ROOT_PASSWORD=${MONGO_ROOT_PASSWORD}|" .env || true
    sed -i.bak "s|^MONGO_APP_PASSWORD=.*$|MONGO_APP_PASSWORD=${MONGO_APP_PASSWORD}|" .env || true
    # Compose prefers an explicit, URL-encoded URI for safety
    PW_ENC=$(python3 - <<'PY'
import os,urllib.parse
print(urllib.parse.quote(os.environ.get('MONGO_APP_PASSWORD',''), safe=''))
PY
    ) || PW_ENC="${MONGO_APP_PASSWORD}"
    sed -i.bak "s|^MONGO_URI=.*$|MONGO_URI=mongodb://chatfleet:${PW_ENC}@mongo:27017/chatfleet?authSource=admin|" .env || true
    rm -f .env.bak || true
    log "Wrote secrets to $INSTALL_DIR/.env"
  else
    log ".env already exists; not modifying"
  fi
  # Ensure tags exist and are non-empty; otherwise default to 'latest'
  resolve_tag() {
    local repo="$1"
    local fallback="$2"
    local t
    t=$(curl -fsSL "https://api.github.com/repos/${repo}/releases/latest" 2>/dev/null | sed -n 's/^\s*\"tag_name\"\s*:\s*\"\(.*\)\".*/\1/p' | head -n1 || true)
    if [ -n "$t" ]; then echo "$t"; else echo "$fallback"; fi
  }
  ensure_tag_kv() {
    local key="$1"; local default_tag="$2"
    if ! grep -q "^${key}=" .env; then
      echo "${key}=${default_tag}" >> .env
      return
    fi
    local cur
    cur=$(sed -n "s/^${key}=\(.*\)$/\1/p" .env | tail -n1)
    if [ -z "$cur" ]; then
      # Replace empty value
      sed -i.bak "s|^${key}=.*$|${key}=${default_tag}|" .env || true
      rm -f .env.bak || true
    fi
  }
  # Compute defaults (prefer provided env, else latest release, else 'latest')
  if [ "$API_TAG_DEFAULT" = "latest" ]; then
    API_TAG_DEFAULT=$(resolve_tag "ChatFleetOSS/chatfleet-api" "latest")
  fi
  if [ "$WEB_TAG_DEFAULT" = "latest" ]; then
    WEB_TAG_DEFAULT=$(resolve_tag "ChatFleetOSS/chatfleet-web" "latest")
  fi
  ensure_tag_kv API_TAG "$API_TAG_DEFAULT"
  ensure_tag_kv WEB_TAG "$WEB_TAG_DEFAULT"
}

# Ensure MONGO_URI exists and is URL-encoded correctly even when .env already existed
repair_mongo_uri_if_needed() {
  cd "$INSTALL_DIR"
  set +e
  # shellcheck disable=SC2046
  . ./.env 2>/dev/null || true
  set -e
  if ! grep -q '^MONGO_URI=' .env; then
    PW_ENC=$(python3 - <<'PY'
import os,urllib.parse
print(urllib.parse.quote(os.environ.get('MONGO_APP_PASSWORD',''), safe=''))
PY
    ) || PW_ENC="${MONGO_APP_PASSWORD}"
    echo "MONGO_URI=mongodb://chatfleet:${PW_ENC}@mongo:27017/chatfleet?authSource=admin" >> .env
    log "Added MONGO_URI to .env"
    return
  fi
  # If password contains characters that likely need encoding and URI doesn't contain %
  if printf '%s' "${MONGO_APP_PASSWORD:-}" | grep -q '[^A-Za-z0-9_]'; then
    if ! grep -q '%40\|%2F\|%3A\|%2B\|%3D\|%25' .env; then
      PW_ENC=$(python3 - <<'PY'
import os,urllib.parse
print(urllib.parse.quote(os.environ.get('MONGO_APP_PASSWORD',''), safe=''))
PY
      ) || PW_ENC="${MONGO_APP_PASSWORD}"
      sed -i.bak "s|^MONGO_URI=.*$|MONGO_URI=mongodb://chatfleet:${PW_ENC}@mongo:27017/chatfleet?authSource=admin|" .env || true
      rm -f .env.bak || true
      log "Updated MONGO_URI with URL-encoded password"
    fi
  fi
}

start_stack() {
  cd "$INSTALL_DIR"
  # Compose picks up API_TAG/WEB_TAG from .env in $INSTALL_DIR
  log "Pulling images (tags from .env)"
  docker compose pull || { log "docker compose pull failed; trying with sudo"; sudo docker compose pull || true; }
  log "Starting services"
  docker compose up -d || { log "docker compose up failed; trying with sudo"; sudo docker compose up -d; }
}

wait_health() {
  local url="http://localhost:8080/api/health"
  log "Waiting for health at $url"
  for i in $(seq 1 60); do
    sleep 2
    if curl -fsS "$url" >/dev/null 2>&1; then
      log "Health OK"
      return 0
    fi
  done
  log "Health not ready; showing logs"
  docker compose -f "$INSTALL_DIR/docker-compose.yml" logs --tail=200 api || sudo docker compose -f "$INSTALL_DIR/docker-compose.yml" logs --tail=200 api || true
  return 1
}

main() {
  need_cmd git; need_cmd curl
  install_docker_if_needed
  need_cmd docker
  docker compose version >/dev/null 2>&1 || die "Docker Compose v2 not available"
  ensure_repo
  ensure_env
  repair_mongo_uri_if_needed
  start_stack
  if wait_health; then
    IP=$(hostname -I 2>/dev/null | awk '{print $1}')
    HOST=${IP:-localhost}
    echo
    echo "ChatFleet is running: http://${HOST}:8080"
    echo "Health: http://${HOST}:8080/api/health"
    echo "Repo dir: $INSTALL_DIR"
    echo "Secrets: $INSTALL_DIR/.env"
    echo "Next steps: Register at /login, then promote your user to admin in Mongo (see DEPLOYMENT.md)."
  else
    die "Startup failed; inspect logs above."
  fi
}

main "$@"
