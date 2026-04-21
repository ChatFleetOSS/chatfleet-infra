# ChatFleet Infra — Quick Install and Upgrade

Quick commands for end users and operators. See `DEPLOYMENT.md` for SSH deploy.
For a developer or power user installing ChatFleet on a brand new machine, read `docs/DEVELOPER_SETUP.md`.
That guide includes:
- exact prerequisites (`git`, `curl`, `python3`, Docker, Compose)
- the implicit prep steps on macOS and Linux before running ChatFleet
- the exact `curl | bash` commands for `stable`, `edge`, and first-admin creation
- what the installer does internally step by step
- what to verify immediately after install
- where files, secrets, volumes, and useful endpoints live
- how to upgrade without data loss
- how to reinstall, reset, and troubleshoot the most common failures

Release promotion and anti-drift process: `docs/RELEASE_PROCESS.md`.

## Quick Install (HTTP :8080)

```
curl -fsSL "https://raw.githubusercontent.com/ChatFleetOSS/chatfleet-infra/main/install.sh?$(date +%s)" | bash
```

Default behavior:
- installs from the committed `stable` channel in `channels/stable.env`
- writes `CHATFLEET_CHANNEL`, `API_TAG`, and `WEB_TAG` into `.env`
- verifies the live API and web build versions after startup
- expects Docker to be running, `:8080` to be free, and enough local disk for the first image pull

Options:
- `CREATE_ADMIN=1` — prompt/confirm admin email and create a pending admin promotion.
  The first successful login with that email is immediately upgraded to admin (no delay).
- `ADMIN_EMAIL=you@example.com` — non‑interactive email for admin promotion.
- `EDGE=1` (or `CHANNEL=edge`) — use the `edge` channel built from backend/frontend `main`.
- `API_TAG=... WEB_TAG=...` — override the pinned channel pair for a one-off install.

## Upgrade (no data loss)

```
$HOME/chatfleet-infra/upgrade.sh
```

Upgrade to `edge`:

```
CHANNEL=edge $HOME/chatfleet-infra/upgrade.sh
```

Pin a specific pair explicitly:

```
API_TAG=v0.1.14 WEB_TAG=v0.1.16 $HOME/chatfleet-infra/upgrade.sh
```

## Release Process

`chatfleet-infra` is the deployment source of truth.

1. Merge backend/frontend changes to `main`.
   Their CI publishes `edge` and immutable `sha-...` images.
2. Validate the new pair with a fresh-machine install using `CHANNEL=edge`.
3. Create semver tags in `chatfleet-api` and `chatfleet-web`.
   Their release workflows publish versioned images, `latest`, and GitHub Releases.
4. Update `channels/stable.env` in this repo to the exact API/Web tags to install by default.
5. Merge infra only after the infra CI smoke test passes against that pinned pair.

Bootstrap order for the first rollout of this process:
1. Merge `chatfleet-infra` first so downstream backend/frontend CI can clone the new channel scripts.
2. Merge backend and frontend to `main` so their `publish-main` jobs create the `edge` images.
3. Run infra `workflow_dispatch` (or wait for the nightly schedule) to validate the `edge` channel.
4. Promote the desired semver pair through the `Promote Channel` workflow, which opens the PR updating `channels/stable.env`.
