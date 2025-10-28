# ChatFleet Infra — Agent Notes

Scope: this repo provides the installer (`install.sh`), Compose stack, and deployment docs for running ChatFleet (API, Web, Caddy).

## Key Files
- Installer: `install.sh`
- Compose: `docker-compose.yml`
- Docs: `README.md`, `DEPLOYMENT.md`, `docs/DEVELOPER_SETUP.md`

## Channels
- Stable: tags `vX.Y.Z` and `:latest` (images published on tag)
- Edge: `:edge` (images published on `main`)

## Related Repos
- Backend API: `ChatFleetOSS/chatfleet-api`
  - Agent guide: `backend/AGENTS.md`
  - API ref: `backend/API_REFERENCE.md`
  - Schemas: `backend/schemas/`
  - Pacts: `backend/tests/contract/`, artifacts in `backend/pacts/`
- Frontend Web: `ChatFleetOSS/chatfleet-web`
  - Agent guide: `frontend/chatFleet_frontend/AGENTS.md`
  - API ref: `frontend/chatFleet_frontend/API_REFERENCE.md`
  - Schemas: `frontend/chatFleet_frontend/schemas/index.ts`
  - Pact artifact: `frontend/chatFleet_frontend/pacts/ChatFleet-Frontend-ChatFleet-API.json`

## Session Handoff
- See `codex.txt` in this repo for a concise summary of the latest work, tags, and how to resume.
