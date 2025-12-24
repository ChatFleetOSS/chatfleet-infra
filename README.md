# ChatFleet Infra — Quick Install and Upgrade

Quick commands for end users and operators. See `DEPLOYMENT.md` for SSH deploy and `docs/DEVELOPER_SETUP.md` for detailed troubleshooting.

## Quick Install (HTTP :8080)

```
curl -fsSL "https://raw.githubusercontent.com/ChatFleetOSS/chatfleet-infra/main/install.sh?$(date +%s)" | bash
```

Options:
- `CREATE_ADMIN=1` — prompt/confirm admin email and create a pending admin promotion.
  The first successful login with that email is immediately upgraded to admin (no delay).
- `ADMIN_EMAIL=you@example.com` — non‑interactive email for admin promotion.
- `EDGE=1` (or `CHANNEL=edge`) — use `:edge` images built from `main`.

## Upgrade (no data loss)

```
cd $HOME/chatfleet-infra
git pull --ff-only
docker compose pull
docker compose up -d --remove-orphans
curl -fsS http://localhost:8080/api/health
```

Pin a specific release:

```
echo 'API_TAG=v0.1.5' >> .env
echo 'WEB_TAG=v0.1.5' >> .env
docker compose pull && docker compose up -d --remove-orphans
```

Use the edge channel:

```
echo 'API_TAG=edge' >> .env
echo 'WEB_TAG=edge' >> .env
docker compose pull && docker compose up -d --remove-orphans
```
