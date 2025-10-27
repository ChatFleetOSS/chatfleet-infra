#!/usr/bin/env bash
set -euo pipefail

INSTALL_DIR="${INSTALL_DIR:-/opt/chatfleet-infra}"
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
    die "Docker/Compose not found. Re-run with INSTALL_DOCKER=1 to auto-install (Debian/Ubuntu), or install Docker Desktop manually."
  fi
  if [ -f /etc/debian_version ]; then
    log "Installing Docker/Compose via convenience script..."
    curl -fsSL https://get.docker.com | sh
    usermod -aG docker "$USER" 2>/dev/null || true
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
    mkdir -p "$INSTALL_DIR"
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
    MONGO_APP_PASSWORD=$(gen_secret)
    sed -i.bak "s|^JWT_SECRET=.*$|JWT_SECRET=${JWT_SECRET}|" .env || true
    sed -i.bak "s|^MONGO_ROOT_USER=.*$|MONGO_ROOT_USER=${MONGO_ROOT_USER}|" .env || true
    sed -i.bak "s|^MONGO_ROOT_PASSWORD=.*$|MONGO_ROOT_PASSWORD=${MONGO_ROOT_PASSWORD}|" .env || true
    sed -i.bak "s|^MONGO_APP_PASSWORD=.*$|MONGO_APP_PASSWORD=${MONGO_APP_PASSWORD}|" .env || true
    rm -f .env.bak || true
    log "Wrote secrets to $INSTALL_DIR/.env"
  else
    log ".env already exists; not modifying"
  fi
}

start_stack() {
  cd "$INSTALL_DIR"
  export API_TAG="$API_TAG_DEFAULT" WEB_TAG="$WEB_TAG_DEFAULT"
  log "Pulling images (api=$API_TAG, web=$WEB_TAG)"
  docker compose pull || true
  log "Starting services"
  docker compose up -d
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
  docker compose -f "$INSTALL_DIR/docker-compose.yml" logs --tail=200 api || true
  return 1
}

main() {
  need_cmd git; need_cmd curl
  install_docker_if_needed
  need_cmd docker
  docker compose version >/dev/null 2>&1 || die "Docker Compose v2 not available"
  ensure_repo
  ensure_env
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

