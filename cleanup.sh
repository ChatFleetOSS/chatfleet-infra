#!/usr/bin/env bash
# Clean up ChatFleet Docker resources for a fresh install.
# Idempotent; skips anything not present. Designed for macOS/Linux with Docker.

set -Eeuo pipefail
IFS=$'\n\t'

INSTALL_DIR="${INSTALL_DIR:-$HOME/chatfleet-infra}"
NONINTERACTIVE="${FORCE:-0}"

note() { printf "[cleanup] %s\n" "$*"; }
warn() { printf "[cleanup] WARN: %s\n" "$*" >&2; }
die()  { printf "[cleanup] ERROR: %s\n" "$*" >&2; exit 1; }

confirm() {
  if [[ "$NONINTERACTIVE" == "1" ]]; then
    return 0
  fi
  echo "This will stop and remove ChatFleet containers, volumes, and images." >&2
  echo "It will NOT touch unrelated Docker resources." >&2
  read -r -p "Type YES to continue: " ans || true
  [[ "$ans" == "YES" ]] || die "Aborted."
}

down_compose() {
  local compose_file="$INSTALL_DIR/docker-compose.yml"
  if [[ -f "$compose_file" ]]; then
    note "Stopping compose stack at $compose_file"
    if docker compose -f "$compose_file" down -v --remove-orphans 2>/dev/null; then
      :
    else
      warn "docker compose failed; retrying with sudo"
      sudo docker compose -f "$compose_file" down -v --remove-orphans || warn "compose down failed"
    fi
  else
    note "No compose file at $compose_file (skip)"
  fi
}

rm_containers() {
  note "Removing standalone dev containers (if any)"
  docker rm -f cf-mongo 2>/dev/null || true
  # Remove any stray chatfleet- prefixed containers from previous compose runs (portable, no mapfile)
  docker ps -a --format '{{.Names}}' | grep -E '^chatfleet-' | while read -r cname; do
    [ -n "$cname" ] && docker rm -f "$cname" || true
  done || true
}

rm_volumes() {
  note "Removing ChatFleet volumes"
  docker volume ls --format '{{.Name}}' | grep -E '^chatfleet_' | while read -r v; do
    [ -n "$v" ] && docker volume rm "$v" || true
  done || true
}

rm_images() {
  note "Removing ChatFleet images from GHCR (local cache)"
  docker images --format '{{.Repository}} {{.ID}}' | awk '$1 ~ /ghcr\.io\/chatfleetoss\// {print $2}' | while read -r iid; do
    [ -n "$iid" ] && docker rmi -f "$iid" || true
  done || true
}

rm_networks() {
  note "Removing ChatFleet default network (if present)"
  docker network rm chatfleet_default 2>/dev/null || true
}

main() {
  confirm
  down_compose
  rm_containers
  rm_volumes
  rm_images
  rm_networks
  note "Cleanup complete. You can now run a fresh install, e.g.:"
  echo "  curl -fsSL \"https://raw.githubusercontent.com/ChatFleetOSS/chatfleet-infra/main/install.sh?\$(date +%s)\" | API_TAG=latest WEB_TAG=latest CREATE_ADMIN=1 ADMIN_EMAIL=\"dev@example.com\" bash"
}

main "$@"
