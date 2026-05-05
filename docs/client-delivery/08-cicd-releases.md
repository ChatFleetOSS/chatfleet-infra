# 08 - CI/CD, releases et publication d'images

## Repositories

| Repo | Role |
| --- | --- |
| `ChatFleetOSS/chatfleet-api` | Backend API, image API |
| `ChatFleetOSS/chatfleet-web` | Frontend Web, image Web |
| `ChatFleetOSS/chatfleet-infra` | Installateur, compose, channels |

## Channels

| Channel | Source | Usage |
| --- | --- | --- |
| `stable` | `channels/stable.env` | Installations clients |
| `edge` | tags Docker `:edge` | Validation de `main` |

Le channel stable actuel:

```env
API_TAG=v0.1.18
WEB_TAG=v0.1.20
```

## Flow release standard

1. Merger API et Web sur `main`.
2. Laisser CI publier `edge`.
3. Taguer API: `vX.Y.Z`.
4. Taguer Web: `vX.Y.Z`.
5. Attendre les workflows release.
6. Verifier les manifests GHCR.
7. Promouvoir `channels/stable.env` dans `chatfleet-infra`.
8. Attendre Infra CI.
9. Mettre a jour les GitHub Releases publiques.

## Commandes tag release

API:

```bash
cd backend
git checkout main
git pull --ff-only
git tag -a v0.1.18 -m "Release v0.1.18"
git push origin v0.1.18
```

Web:

```bash
cd frontend/chatFleet_frontend
git checkout main
git pull --ff-only
git tag -a v0.1.20 -m "Release v0.1.20"
git push origin v0.1.20
```

## Verification GHCR

```bash
docker manifest inspect ghcr.io/chatfleetoss/chatfleet-api:v0.1.18
docker manifest inspect ghcr.io/chatfleetoss/chatfleet-web:v0.1.20
```

Attendu:

- `linux/amd64`;
- `linux/arm64`.

## Workflows API

Le workflow API execute notamment:

- sanity;
- ruff non bloquant + compileall;
- mypy non bloquant;
- Pact consumer;
- Pact provider verify;
- build Docker;
- budget taille image;
- Trivy;
- Gitleaks;
- SBOM;
- infra smoke avec Web stable;
- publication `edge` sur `main`;
- release multi-arch sur tag.

## Workflows Web

Le workflow Web execute notamment:

- `npm ci`;
- `tsc --noEmit` non bloquant;
- `next build`;
- lint non bloquant;
- build Docker;
- budget taille image;
- Trivy;
- Gitleaks;
- SBOM;
- infra smoke avec API stable;
- publication `edge` sur `main`;
- release multi-arch sur tag.

## Workflows Infra

Infra CI valide:

- references d'images stable;
- flow promotion;
- installation stable;
- verification versions live.

## Cosign

Les images release sont signees en keyless.

Verification type:

```bash
cosign verify ghcr.io/chatfleetoss/chatfleet-api:v0.1.18
cosign verify ghcr.io/chatfleetoss/chatfleet-web:v0.1.20
```

Selon environnement, il peut etre necessaire de configurer les options de verification keyless adaptees a GitHub Actions.

