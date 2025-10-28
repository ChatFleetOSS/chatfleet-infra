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

Flags: `CREATE_ADMIN=1`, `ADMIN_EMAIL=you@example.com`, `EDGE=1`/`CHANNEL=edge`, `INSTALL_DIR`, `INSTALL_DOCKER=1` (Linux)

## Upgrade
```
cd $HOME/chatfleet-infra
git pull --ff-only
docker compose pull
docker compose up -d --remove-orphans
curl -fsS http://localhost:8080/api/health
```

Pin releases or use edge by setting `API_TAG`/`WEB_TAG` in `.env`.

## Common Fixes
- Mongo unhealthy after reinstall → remove volume `chatfleet_mongo_data` (data loss) or align creds.
- API URI/auth errors → ensure encoded `MONGO_URI` with `authSource=chatfleet`; installer writes this.
- App user missing → init now passes `MONGO_APP_PASSWORD`; create manually if needed.
- 502 via Caddy → warm‑up; retry after a few seconds.

