# ChatFleet Infra Deploy (SSH)

## Server setup (once)
- Create deploy user and grant Docker:
  sudo useradd -m deploy && sudo usermod -aG docker deploy
- Install Docker, Docker Compose v2, Cosign.
- Clone repo to /opt:
  sudo mkdir -p /opt && sudo chown deploy:deploy /opt
  git clone <this-repo-url> /opt/chatfleet-infra
- Create /opt/chatfleet-infra/.env with:
  JWT_SECRET, MONGO_ROOT_USER, MONGO_ROOT_PASSWORD, MONGO_APP_PASSWORD, optional OPENAI_API_KEY
- Add SSH public key to /home/deploy/.ssh/authorized_keys

## GitHub Secrets (this repo)
- SSH_HOST: server IP/hostname
- SSH_USER: deploy
- SSH_KEY: private key (PEM) for deploy user
- GHCR_PAT: read:packages token for GHCR pulls

## Deploy
- Release images by tagging backend/frontend repos (e.g., v1.0.0)
- In this repo → Actions → “Deploy (SSH)”
- Enter api_tag/web_tag (e.g., v1.0.0), run
- App at: http://<server>:8080

## HTTPS (optional, end-user domain)
- Provide a domain and switch to a TLS Caddyfile mapping 80/443
- Keep HTTP 8080 as the default for zero-config installs

## One-liner installer (HTTP :8080)
For quick local/server setup without SSH deploy, run:

curl -fsSL "https://raw.githubusercontent.com/ChatFleetOSS/chatfleet-infra/main/install.sh?$(date +%s)" | bash

Defaults:
- Installs to `$HOME/chatfleet-infra` (no sudo). Use `USE_SYSTEM=1` to install to `/opt/chatfleet-infra` (prompts for sudo once).
- Attempts to resolve the latest release tags automatically; you can override via `API_TAG` and `WEB_TAG`.
- On Linux (Debian/Ubuntu), set `INSTALL_DOCKER=1` to auto-install Docker; on macOS, start Docker Desktop manually.

## Upgrade

To upgrade an existing installation without losing data:

1. Pull infra and images, then restart

```
cd $HOME/chatfleet-infra
git pull --ff-only
docker compose pull
docker compose up -d --remove-orphans
curl -fsS http://localhost:8080/api/health
```

2. Pin a specific release (optional)

Edit `.env` and set the tags you want to use, then pull and restart:

```
echo 'API_TAG=v0.1.5' >> .env
echo 'WEB_TAG=v0.1.5' >> .env
docker compose pull
docker compose up -d --remove-orphans
```

3. Use the edge channel (main snapshots)

```
echo 'API_TAG=edge' >> .env
echo 'WEB_TAG=edge' >> .env
docker compose pull
docker compose up -d --remove-orphans
```

Notes:
- Do not delete volumes during upgrades; that would wipe Mongo data.
- Health should return `status: ok` after the restart.
