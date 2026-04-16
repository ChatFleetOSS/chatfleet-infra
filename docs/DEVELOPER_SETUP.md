# ChatFleet — Developer Install & Troubleshooting (Infra copy)

This copy mirrors the top-level `docs/DEVELOPER_SETUP.md` for convenience in the infra repo.

## Prerequisites
- Docker Desktop (macOS/Windows) or Docker Engine + Compose v2 (Linux)
- Internet access to GHCR (`ghcr.io/chatfleetoss/*`)
- Optional: `gh` CLI to watch CI

## One‑Liner Install
```
curl -fsSL "https://raw.githubusercontent.com/ChatFleetOSS/chatfleet-infra/main/install.sh?$(date +%s)" | bash
```

Flags: `CREATE_ADMIN=1`, `ADMIN_EMAIL=you@example.com`, `EDGE=1`/`CHANNEL=edge`, `API_TAG`, `WEB_TAG`, `INSTALL_DIR`, `INSTALL_DOCKER=1` (Linux)

By default the installer resolves the committed `stable` channel from `channels/stable.env` and persists that exact pair in `.env`.

## Upgrade
```
$HOME/chatfleet-infra/upgrade.sh
```

Use `CHANNEL=edge` for main snapshots, or override with `API_TAG` / `WEB_TAG` for a one-off pin.

## Promotion Discipline
- `channels/stable.env` is the machine-neuve default and must only contain explicit release tags.
- `channels/edge.env` tracks the latest backend/frontend `main` images.
- Backend/frontend release tags are not “live” for installs until infra updates `channels/stable.env`.
- Infra CI smoke-tests the pinned pair and checks the versions served by `/api/health` and `/build-info`.
- Stable promotions should go through the `Promote Channel` workflow or `scripts/promote_channel.py`, not manual edits.

## Common Fixes
- Mongo unhealthy after reinstall → remove volume `chatfleet_mongo_data` (data loss) or align creds.
- API URI/auth errors → ensure encoded `MONGO_URI` with `authSource=chatfleet`; installer writes this.
- App user missing → init now passes `MONGO_APP_PASSWORD`; create manually if needed.
- 502 via Caddy → warm‑up; retry after a few seconds.
