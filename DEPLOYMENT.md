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
- GHCR_USERNAME: GitHub username owning the `GHCR_PAT`
- GHCR_PAT: read:packages token for GHCR pulls

## Deploy
- Release images by tagging backend/frontend repos (e.g., `v1.0.0`)
- Update `channels/stable.env` in this repo to the exact pair you want to deploy by default
- In this repo → Actions → “Deploy (SSH)”
- Run it with the default `channel=stable`, or override `api_tag` / `web_tag` for a one-off deploy
- App at: http://<server>:8080

## HTTPS (optional, end-user domain)
- Provide a domain and switch to a TLS Caddyfile mapping 80/443
- Keep HTTP 8080 as the default for zero-config installs

## One-liner installer (HTTP :8080)
For quick local/server setup without SSH deploy, run:

curl -fsSL "https://raw.githubusercontent.com/ChatFleetOSS/chatfleet-infra/main/install.sh?$(date +%s)" | bash

Defaults:
- Installs to `$HOME/chatfleet-infra` (no sudo). Use `USE_SYSTEM=1` to install to `/opt/chatfleet-infra` (prompts for sudo once).
- Uses the committed `stable` channel from `channels/stable.env`; you can override via `CHANNEL`, `API_TAG`, and `WEB_TAG`.
- On Linux (Debian/Ubuntu), set `INSTALL_DOCKER=1` to auto-install Docker; the installer also bootstraps missing `git` and `python3`.
- If Docker is installed but the current session does not yet have Docker-group access, the installer retries Compose with `sudo`.
- On macOS, start Docker Desktop manually or let the installer try to open it and wait for readiness.
- Verifies that `/api/health` and `/build-info` return the expected build versions after startup.

Admin setup:
- To have the first admin available immediately on login, pass `CREATE_ADMIN=1 ADMIN_EMAIL=you@example.com` to the installer. The installer creates a 48h promotion intent in Mongo; the first successful login with that email is upgraded to admin before the token is issued (no delay).
- If you prefer manual promotion, you can still run the `mongosh` one-liner from `README.md` to set `{role:"admin"}` for any existing user.

## Upgrade

To upgrade an existing installation without losing data:

1. Pull infra and images, then restart

```
$HOME/chatfleet-infra/upgrade.sh
```

2. Move to the `edge` channel (optional)

```
CHANNEL=edge $HOME/chatfleet-infra/upgrade.sh
```

3. Pin a specific pair (optional)

```
API_TAG=v0.1.14 WEB_TAG=v0.1.16 $HOME/chatfleet-infra/upgrade.sh
```

Notes:
- Do not delete volumes during upgrades; that would wipe Mongo data.
- `upgrade.sh` rewrites `.env` so the deployed `CHATFLEET_CHANNEL`, `API_TAG`, and `WEB_TAG` stay explicit.
- Health should return `status: ok` after the restart, and `/build-info` should match the expected web tag.

## Promotion Flow

Use this flow to prevent infra drift as backend/frontend code evolves:

1. Backend/frontend `main` stays deployable through the `edge` channel.
2. New-machine smoke validation is done with `CHANNEL=edge`.
3. Semver tags are cut in `chatfleet-api` and `chatfleet-web` once the pair is validated.
4. `channels/stable.env` is updated in `chatfleet-infra` to the exact release tags.
5. Infra CI must pass before merging that promotion PR.

Initial rollout order for these guardrails:
1. Merge `chatfleet-infra` first.
2. Merge backend/frontend so `edge` images are published from `main`.
3. Trigger infra edge validation manually once those images exist.
4. Promote the final release tags through the `Promote Channel` workflow.
