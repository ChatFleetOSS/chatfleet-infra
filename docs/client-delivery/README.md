# ChatFleet - Dossier technique client

Version du dossier: 2026-05-05  
Perimetre documente:

- Backend API: `ChatFleetOSS/chatfleet-api`, release stable `v0.1.18`
- Frontend Web: `ChatFleetOSS/chatfleet-web`, release stable `v0.1.20`
- Infra installateur: `ChatFleetOSS/chatfleet-infra`, channel `stable`
- Images: `ghcr.io/chatfleetoss/chatfleet-api:v0.1.18` et `ghcr.io/chatfleetoss/chatfleet-web:v0.1.20`

Ce dossier est une documentation technique de livraison. Il decrit l'etat reel de la plateforme tel qu'il est implemente dans le code: FastAPI, Next.js, MongoDB, FAISS, Caddy, Docker Compose, pipelines GitHub Actions, installateur `curl | bash`, ingestion OpenDocument et prompt RAG configurable.

## Documents

1. [Synthese executive technique](./01-synthese-technique.md)
2. [Architecture applicative et technique](./02-architecture.md)
3. [Installation, configuration et mise a jour](./03-installation-configuration-mise-a-jour.md)
4. [Exploitation, supervision et runbooks](./04-exploitation-runbooks.md)
5. [Contrats API et integration](./05-api-integration.md)
6. [RAG, ingestion documentaire et prompts configurables](./06-rag-ingestion-prompts.md)
7. [Securite, secrets et donnees](./07-securite.md)
8. [CI/CD, releases et publication d'images](./08-cicd-releases.md)
9. [Frontend, UX admin et integration web](./09-frontend.md)
10. [Tests, recette et criteres d'acceptation](./10-tests-recette.md)
11. [Annexes: commandes et aide au diagnostic](./11-annexes-commandes.md)

## Etat fonctionnel livre

La plateforme permet:

- l'authentification par JWT;
- la gestion d'utilisateurs et de droits d'acces par RAG;
- la creation, configuration, exposition publique ou privee et suppression de RAG;
- l'upload et l'indexation de documents `PDF`, `DOCX`, `TXT`, `ODT`, `ODS`, `ODP`;
- le chat RAG avec citations;
- le chat public pour les RAG marques `public`;
- la configuration runtime du fournisseur LLM (`openai` ou `vllm`) et du fournisseur d'embeddings (`openai` ou `local`);
- la personnalisation du prompt systeme RAG par assistant;
- l'installation et la mise a jour par installateur public GitHub.

## Matrice des versions stables

| Composant | Version | Image / Source |
| --- | --- | --- |
| API | `v0.1.18` | `ghcr.io/chatfleetoss/chatfleet-api:v0.1.18` |
| Web | `v0.1.20` | `ghcr.io/chatfleetoss/chatfleet-web:v0.1.20` |
| Infra | `main`, commit `97140b4` ou plus recent | `channels/stable.env` |
| MongoDB | `mongo:6` | Service Compose |
| Reverse proxy | `caddy:2.8-alpine` | Service Compose |

Les images API et Web sont publiees en multi-architecture `linux/amd64` et `linux/arm64`.

## Installation rapide

Nouvelle installation:

```bash
curl -fsSL "https://raw.githubusercontent.com/ChatFleetOSS/chatfleet-infra/main/install.sh?$(date +%s)" | bash
```

Mise a jour d'une installation existante:

```bash
$HOME/chatfleet-infra/upgrade.sh
```

Verification:

```bash
curl -fsS http://localhost:8080/api/health
curl -fsS http://localhost:8080/build-info
```

## Sources de verite

- Le fichier `channels/stable.env` de `chatfleet-infra` definit la paire API/Web installee par defaut.
- `install.sh` et `upgrade.sh` resolvent ce channel avant de lancer `docker compose`.
- `backend/app/routes` definit les endpoints API.
- `backend/app/models` et `frontend/chatFleet_frontend/schemas/index.ts` definissent les schemas contractuels.
- `frontend/chatFleet_frontend/lib/apiClient.ts` definit les appels API effectues par le Web.

