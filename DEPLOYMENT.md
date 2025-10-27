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
