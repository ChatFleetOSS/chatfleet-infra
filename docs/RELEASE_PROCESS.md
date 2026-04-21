# ChatFleet Release Process

This is the source of truth for promoting backend/frontend versions into `chatfleet-infra`.

## Goals
- a fresh machine always installs the exact pair committed in `channels/stable.env`
- backend/frontend `main` snapshots are validated through the `edge` channel
- stable promotions happen through a scripted PR flow, not by editing files manually

## Normal Flow
1. Merge `chatfleet-infra` changes first when the process or channel scripts evolve.
2. Merge backend and frontend changes to `main`.
   Their CI publishes only after the repo-level validation jobs are green:
   - backend: consumer pact, provider verify, infra smoke
   - frontend: build checks, infra smoke
   Then it publishes:
   - `edge`
   - `sha-<commit>`
3. Validate the latest `main` pair with the infra `edge` channel.
   Use the infra `Infra CI` workflow manually or wait for the nightly run.
   The mutable `edge` tag still reports an internal build version like `sha-<commit>`;
   the smoke test verifies that prefix instead of comparing to the literal string `edge`.
4. Cut release tags in `chatfleet-api` and `chatfleet-web`.
5. Run the infra workflow `Promote Channel`.
   Inputs:
   - `channel=stable`
   - `api_tag=<released api tag>`
   - `web_tag=<released web tag>`
6. Review and merge the generated PR in `chatfleet-infra`.
   Infra CI smoke-tests that pair before merge.

## Why This Prevents Drift
- `install.sh` and `upgrade.sh` resolve a committed channel file, not `latest`
- `promote_channel.py` validates tag format and GHCR presence before changing a channel
- infra CI exercises the promotion logic over three successive release pairs
- channel promotion fails fast if the target tags do not exist yet in GHCR
- backend CI smoke-tests the local backend against the stable frontend in infra
- frontend CI smoke-tests the local frontend against the stable backend in infra

## Local Simulation
For local dry-runs or preflight checks:

```bash
python3 ./scripts/promote_channel.py --channel stable --api-tag v0.1.14 --web-tag v0.1.16 --verify-only
python3 ./scripts/test_promotion_flow.py
```

To test a local temporary pair without touching `stable`, use explicit overrides:

```bash
INSTALL_DIR=/tmp/chatfleet-sim \
SKIP_PULL=1 \
SKIP_VERIFY=1 \
API_TAG=<local-api-tag> \
WEB_TAG=<local-web-tag> \
CHANNEL=stable \
bash ./install.sh
```
