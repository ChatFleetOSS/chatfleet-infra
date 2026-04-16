#!/usr/bin/env bash
set -euo pipefail

# Install location
# Default to user home for least-privilege installs; set USE_SYSTEM=1 to opt into /opt
if [ "${USE_SYSTEM:-0}" = "1" ]; then
  INSTALL_DIR="${INSTALL_DIR:-/opt/chatfleet-infra}"
else
  INSTALL_DIR="${INSTALL_DIR:-$HOME/chatfleet-infra}"
fi
INFRA_REPO_URL="${INFRA_REPO_URL:-https://github.com/ChatFleetOSS/chatfleet-infra}"
INFRA_SOURCE_DIR="${INFRA_SOURCE_DIR:-}"
INSTALL_DOCKER="${INSTALL_DOCKER:-0}"
SKIP_PULL="${SKIP_PULL:-0}"

log() { echo -e "[chatfleet-install] $*"; }
die() { echo -e "[chatfleet-install][error] $*" >&2; exit 1; }

need_cmd() { command -v "$1" >/dev/null 2>&1 || die "Required command '$1' not found"; }

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
  if [ -n "$INFRA_SOURCE_DIR" ]; then
    log "Syncing infra repo from local source $INFRA_SOURCE_DIR"
    [ -d "$INFRA_SOURCE_DIR" ] || die "INFRA_SOURCE_DIR does not exist: $INFRA_SOURCE_DIR"
    mkdir -p "$INSTALL_DIR"
    cp -R "$INFRA_SOURCE_DIR"/. "$INSTALL_DIR"
    return
  fi
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
    git clone "$INFRA_REPO_URL" "$INSTALL_DIR"
  fi
}

ensure_env() {
  cd "$INSTALL_DIR"
  if [ ! -f .env ]; then
    log "Generating .env with secure defaults"
    cp .env.example .env
    JWT_SECRET=$(gen_secret)
    MONGO_ROOT_USER="root"
    # Generate a hex root password to avoid special-char pitfalls
    if command -v openssl >/dev/null 2>&1; then
      MONGO_ROOT_PASSWORD=$(openssl rand -hex 24 | tr -d '\n')
    else
      MONGO_ROOT_PASSWORD=$(head -c 24 /dev/urandom | od -An -tx1 | tr -d ' \n')
    fi
    # Generate an app password that is URL-safe (hex)
    if command -v openssl >/dev/null 2>&1; then
      MONGO_APP_PASSWORD=$(openssl rand -hex 24 | tr -d '\n')
    else
      MONGO_APP_PASSWORD=$(head -c 24 /dev/urandom | od -An -tx1 | tr -d ' \n')
    fi
    upsert_env_value JWT_SECRET "$JWT_SECRET"
    upsert_env_value MONGO_ROOT_USER "$MONGO_ROOT_USER"
    upsert_env_value MONGO_ROOT_PASSWORD "$MONGO_ROOT_PASSWORD"
    upsert_env_value MONGO_APP_PASSWORD "$MONGO_APP_PASSWORD"
    # Compose prefers an explicit, URL-encoded URI for safety
    PW_ENC=$(env MONGO_APP_PASSWORD="${MONGO_APP_PASSWORD}" python3 - <<'PY'
import os, urllib.parse
val = os.environ.get('MONGO_APP_PASSWORD', '')
print(urllib.parse.quote(val, safe=''))
PY
    )
    # Fallback if encoding yields empty
    if [ -z "${PW_ENC}" ]; then PW_ENC="${MONGO_APP_PASSWORD}"; fi
    upsert_env_value MONGO_URI "mongodb://chatfleet:${PW_ENC}@mongo:27017/chatfleet?authSource=chatfleet"
    log "Wrote secrets to $INSTALL_DIR/.env"
  else
    log ".env already exists; not modifying"
  fi

  STORED_CHANNEL="$(read_env_value CHATFLEET_CHANNEL)"
  eval "$(
    EDGE="${EDGE:-0}" \
    CHANNEL="${CHANNEL:-${STORED_CHANNEL:-}}" \
    CHATFLEET_CHANNEL="${STORED_CHANNEL:-}" \
    API_TAG="${API_TAG:-}" \
    WEB_TAG="${WEB_TAG:-}" \
    bash "$INSTALL_DIR/scripts/resolve-channel.sh"
  )"
  upsert_env_value CHATFLEET_CHANNEL "$CHATFLEET_CHANNEL"
  upsert_env_value API_TAG "$API_TAG"
  upsert_env_value WEB_TAG "$WEB_TAG"
  log "Using deployment channel '$CHATFLEET_CHANNEL' (api=$API_TAG web=$WEB_TAG)"
}

# Ensure MONGO_URI exists and is URL-encoded correctly even when .env already existed
repair_mongo_uri_if_needed() {
  cd "$INSTALL_DIR"
  set +e
  # shellcheck disable=SC2046
  . ./.env 2>/dev/null || true
  set -e
  if ! grep -q '^MONGO_URI=' .env; then
    PW_ENC=$(env MONGO_APP_PASSWORD="${MONGO_APP_PASSWORD}" python3 - <<'PY'
import os, urllib.parse
val = os.environ.get('MONGO_APP_PASSWORD', '')
print(urllib.parse.quote(val, safe=''))
PY
    )
    if [ -z "${PW_ENC}" ]; then PW_ENC="${MONGO_APP_PASSWORD}"; fi
    echo "MONGO_URI=mongodb://chatfleet:${PW_ENC}@mongo:27017/chatfleet?authSource=chatfleet" >> .env
    log "Added MONGO_URI to .env"
    return
  fi
  # If password contains characters that likely need encoding and URI doesn't contain %
  if printf '%s' "${MONGO_APP_PASSWORD:-}" | grep -q '[^A-Za-z0-9_]'; then
    if ! grep -q '%40\|%2F\|%3A\|%2B\|%3D\|%25' .env; then
      PW_ENC=$(env MONGO_APP_PASSWORD="${MONGO_APP_PASSWORD}" python3 - <<'PY'
import os, urllib.parse
val = os.environ.get('MONGO_APP_PASSWORD', '')
print(urllib.parse.quote(val, safe=''))
PY
      )
      if [ -z "${PW_ENC}" ]; then PW_ENC="${MONGO_APP_PASSWORD}"; fi
      sed -i.bak "s|^MONGO_URI=.*$|MONGO_URI=mongodb://chatfleet:${PW_ENC}@mongo:27017/chatfleet?authSource=chatfleet|" .env || true
      rm -f .env.bak || true
      log "Updated MONGO_URI with URL-encoded password"
    fi
  fi
}

start_stack() {
  cd "$INSTALL_DIR"
  # Compose picks up API_TAG/WEB_TAG from .env in $INSTALL_DIR
  if [ "$SKIP_PULL" = "1" ]; then
    log "Skipping docker compose pull (SKIP_PULL=1)"
  else
    log "Pulling images (tags from .env)"
    if ! docker compose pull; then
      if command -v sudo >/dev/null 2>&1 && [ -t 0 ]; then
        log "docker compose pull failed; retrying with sudo"
        sudo docker compose pull
      else
        die "docker compose pull failed; ensure the current user can access Docker."
      fi
    fi
  fi
  log "Starting services"
  if ! docker compose up -d --remove-orphans; then
    if command -v sudo >/dev/null 2>&1 && [ -t 0 ]; then
      log "docker compose up failed; retrying with sudo"
      sudo docker compose up -d --remove-orphans
    else
      die "docker compose up failed; ensure the current user can access Docker."
    fi
  fi
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

prompt_admin_email() {
  if [ -n "${ADMIN_EMAIL:-}" ]; then
    printf "%s" "$ADMIN_EMAIL"
    return 0
  fi
  # Require TTY to prompt
  if [ -t 0 ]; then
    local email1 email2
    while true; do
      read -r -p "Enter admin email: " email1
      read -r -p "Confirm admin email: " email2
      if [ -z "$email1" ] || [ "$email1" != "$email2" ]; then
        echo "Emails do not match or empty. Try again." >&2
        continue
      fi
      printf "%s" "$email1"
      return 0
    done
  else
    echo ""  # no TTY; return empty
  fi
}

create_admin_promotion_intent() {
  # Create a pending admin promotion intent so that the first login upgrades immediately
  local email="$1"
  [ -z "$email" ] && return 0
  set +e
  . "$INSTALL_DIR/.env" 2>/dev/null || true
  set -e
  # 48h validity window
  local hours=48
  # shellcheck disable=SC2016
  if docker compose -f "$INSTALL_DIR/docker-compose.yml" exec -T mongo mongosh --quiet \
    -u "$MONGO_ROOT_USER" -p "$MONGO_ROOT_PASSWORD" --authenticationDatabase admin \
    --eval 'db=db.getSiblingDB("chatfleet"); var now=new Date(); var exp=new Date(now.getTime()+('$hours')*3600*1000); db.admin_promotions.updateOne({email:"'$email'"},{ $setOnInsert:{email:"'$email'", created_at:now, expires_at:exp, redeemed:false}},{upsert:true}); print("INTENT_OK");' \
    | grep -q INTENT_OK; then
    log "Created admin promotion intent for $email (valid ${hours}h)."
    return 0
  else
    log "Could not create admin promotion intent (older API image?). Falling back to polling promotion."
    return 1
  fi
}

promote_admin_if_present() {
  # Promote a registered user to admin by email (if found)
  local email="$1"
  [ -z "$email" ] && return 0
  # Load env
  set +e
  . "$INSTALL_DIR/.env" 2>/dev/null || true
  set -e
  # Try for up to 90s to find and promote
  for i in $(seq 1 18); do
    # shellcheck disable=SC2016
    if docker compose -f "$INSTALL_DIR/docker-compose.yml" exec -T mongo mongosh --quiet \
      -u "$MONGO_ROOT_USER" -p "$MONGO_ROOT_PASSWORD" --authenticationDatabase admin \
      --eval 'db=db.getSiblingDB("chatfleet"); var u=db.users.findOne({email:"'$email'"}); if(u){ db.users.updateOne({email:"'$email'"}, {$set:{role:"admin"}}); print("PROMOTED"); } else { print("NOTFOUND"); }' \
      | grep -q PROMOTED; then
      log "Promoted $email to admin."
      return 0
    fi
    sleep 5
  done
  log "Admin email '$email' not found yet. After registering in the UI, promote manually with:"
  echo "  docker compose -f '$INSTALL_DIR/docker-compose.yml' exec mongo mongosh --quiet -u \"$MONGO_ROOT_USER\" -p \"$MONGO_ROOT_PASSWORD\" --authenticationDatabase admin --eval 'db=db.getSiblingDB(\"chatfleet\"); db.users.updateOne({email:\"$email\"}, {\$set:{role:\"admin\"}})'"
}

main() {
  need_cmd git; need_cmd curl; need_cmd python3
  install_docker_if_needed
  need_cmd docker
  docker compose version >/dev/null 2>&1 || die "Docker Compose v2 not available"
  ensure_repo
  ensure_env
  repair_mongo_uri_if_needed
  start_stack
  if wait_health; then
    python3 "$INSTALL_DIR/scripts/verify_stack.py" \
      --base-url "http://localhost:8080" \
      --expected-api "$API_TAG" \
      --expected-web "$WEB_TAG"
    IP=$(hostname -I 2>/dev/null | awk '{print $1}')
    HOST=${IP:-localhost}
    echo
    echo "ChatFleet is running: http://${HOST}:8080"
    echo "Health: http://${HOST}:8080/api/health"
    echo "Build info: http://${HOST}:8080/build-info"
    echo "Channel: ${CHATFLEET_CHANNEL}"
    echo "Images: api=${API_TAG} web=${WEB_TAG}"
    echo "Repo dir: $INSTALL_DIR"
    echo "Secrets: $INSTALL_DIR/.env"
    echo "Next steps: Register at /login, then promote your user to admin in Mongo (see DEPLOYMENT.md)."
    if [ "${CREATE_ADMIN:-0}" = "1" ]; then
      local ADMIN_ADDR
      ADMIN_ADDR=$(prompt_admin_email)
      if [ -n "$ADMIN_ADDR" ]; then
        # Best effort: prefer intent creation for immediate upgrade at login; otherwise fall back to poll
        if ! create_admin_promotion_intent "$ADMIN_ADDR"; then
          log "Will attempt to auto-promote '$ADMIN_ADDR' to admin once registered."
          promote_admin_if_present "$ADMIN_ADDR"
        else
          log "On first login, '$ADMIN_ADDR' will be upgraded to admin immediately."
        fi
      else
        log "CREATE_ADMIN=1 set but no email provided (no TTY?). Skipping auto-promotion."
      fi
    fi
  else
    die "Startup failed; inspect logs above."
  fi
}

main "$@"
