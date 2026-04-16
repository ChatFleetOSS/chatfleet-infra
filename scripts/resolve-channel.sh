#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CHANNEL_NAME="${CHANNEL:-${CHATFLEET_CHANNEL:-stable}}"
API_TAG_OVERRIDE="${API_TAG:-}"
WEB_TAG_OVERRIDE="${WEB_TAG:-}"

if [ "${EDGE:-0}" = "1" ]; then
  CHANNEL_NAME="edge"
fi

CHANNEL_FILE="${ROOT_DIR}/channels/${CHANNEL_NAME}.env"
[ -f "$CHANNEL_FILE" ] || {
  echo "Unknown channel '${CHANNEL_NAME}' (expected ${CHANNEL_FILE})" >&2
  exit 1
}

set -a
. "$CHANNEL_FILE"
set +a

if [ -n "$API_TAG_OVERRIDE" ]; then
  API_TAG="$API_TAG_OVERRIDE"
fi

if [ -n "$WEB_TAG_OVERRIDE" ]; then
  WEB_TAG="$WEB_TAG_OVERRIDE"
fi

[ -n "${API_TAG:-}" ] || {
  echo "Resolved API_TAG is empty for channel '${CHANNEL_NAME}'" >&2
  exit 1
}
[ -n "${WEB_TAG:-}" ] || {
  echo "Resolved WEB_TAG is empty for channel '${CHANNEL_NAME}'" >&2
  exit 1
}

printf 'CHATFLEET_CHANNEL=%q\n' "$CHANNEL_NAME"
printf 'API_TAG=%q\n' "$API_TAG"
printf 'WEB_TAG=%q\n' "$WEB_TAG"
