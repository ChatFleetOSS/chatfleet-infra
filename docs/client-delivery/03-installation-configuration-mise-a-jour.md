# 03 - Installation, configuration et mise a jour

## Pre-requis

- Docker Desktop ou Docker Engine;
- Docker Compose v2;
- acces a Internet vers GitHub et GHCR;
- port `8080` libre;
- `curl`, `git`, `python3`;
- sur Linux, utilisateur autorise a utiliser Docker, ou `sudo` disponible.

## Installation standard

```bash
curl -fsSL "https://raw.githubusercontent.com/ChatFleetOSS/chatfleet-infra/main/install.sh?$(date +%s)" | bash
```

Par defaut, l'installateur:

1. clone ou met a jour `ChatFleetOSS/chatfleet-infra`;
2. installe dans `$HOME/chatfleet-infra` sauf si `USE_SYSTEM=1`;
3. resout le channel `stable`;
4. genere les secrets manquants dans `.env`;
5. ecrit `CHATFLEET_CHANNEL`, `API_TAG`, `WEB_TAG`;
6. demarre `mongo`, `api`, `web`, `caddy`;
7. verifie `http://localhost:8080/api/health`;
8. verifie les versions live API/Web.

## Installation avec creation admin

```bash
CREATE_ADMIN=1 ADMIN_EMAIL="admin@example.com" \
curl -fsSL "https://raw.githubusercontent.com/ChatFleetOSS/chatfleet-infra/main/install.sh?$(date +%s)" | bash
```

Au premier login ou register avec cet email, le backend applique une promotion admin en attente.

## Installation edge

```bash
EDGE=1 curl -fsSL "https://raw.githubusercontent.com/ChatFleetOSS/chatfleet-infra/main/install.sh?$(date +%s)" | bash
```

Le channel `edge` utilise les images `:edge` publiees depuis `main`. Il est reserve aux validations ou preproductions.

## Pinning explicite

```bash
API_TAG=v0.1.18 WEB_TAG=v0.1.20 \
curl -fsSL "https://raw.githubusercontent.com/ChatFleetOSS/chatfleet-infra/main/install.sh?$(date +%s)" | bash
```

## Configuration `.env`

Fichier: `$HOME/chatfleet-infra/.env`.

| Variable | Requis | Description |
| --- | --- | --- |
| `JWT_SECRET` | Oui | Secret JWT fort, 32 caracteres minimum. |
| `MONGO_ROOT_USER` | Oui | Utilisateur root Mongo. |
| `MONGO_ROOT_PASSWORD` | Oui | Mot de passe root Mongo. |
| `MONGO_APP_PASSWORD` | Oui | Mot de passe de l'utilisateur applicatif `chatfleet`. |
| `MONGO_URI` | Oui | URI applicative Mongo avec mot de passe URL-encode. |
| `CHATFLEET_CHANNEL` | Oui | `stable` ou `edge`. |
| `API_TAG` | Oui | Tag image API resolu. |
| `WEB_TAG` | Oui | Tag image Web resolu. |
| `OPENAI_API_KEY` | Non | Cle OpenAI initiale. Peut etre remplacee par config runtime admin. |
| `SSE_HEARTBEAT_MS` | Non | Heartbeat SSE, defaut `15000`. |
| `TOP_K_DEFAULT` | Non | Nombre de chunks recuperes par defaut, defaut `6` en compose. |
| `TEMPERATURE_DEFAULT` | Non | Temperature LLM, defaut `0.2`. |
| `MAX_UPLOAD_MB` | Non | Taille max upload par fichier, defaut `50`. |
| `CHAT_MODEL` | Non | Modele chat initial, defaut `gpt-4o-mini`. |
| `EMBED_MODEL` | Non | Modele embeddings initial, defaut `text-embedding-3-small`. |

## Mise a jour standard

```bash
$HOME/chatfleet-infra/upgrade.sh
```

L'upgrade:

1. fait un `git pull --ff-only` de l'infra si possible;
2. relit le channel stocke dans `.env`;
3. resout `API_TAG` et `WEB_TAG`;
4. met a jour `.env`;
5. lance `docker compose pull`;
6. lance `docker compose up -d --remove-orphans`;
7. verifie les versions API et Web.

## Verification apres mise a jour

```bash
curl -fsS http://localhost:8080/api/health
curl -fsS http://localhost:8080/build-info
docker compose -f "$HOME/chatfleet-infra/docker-compose.yml" ps
```

La reponse API doit contenir:

```json
{
  "status": "ok",
  "mongo": true,
  "index_dir": true,
  "upload_dir": true,
  "build": {
    "version": "v0.1.18"
  }
}
```

La reponse Web doit contenir:

```json
{
  "name": "chatfleet-web",
  "build": {
    "version": "v0.1.20"
  }
}
```

## Desinstallation

Arret sans suppression de donnees:

```bash
$HOME/chatfleet-infra/uninstall.sh "$HOME/chatfleet-infra"
```

Suppression avec purge des volumes:

```bash
PURGE=1 $HOME/chatfleet-infra/uninstall.sh "$HOME/chatfleet-infra"
```

Attention: `PURGE=1` supprime Mongo, les uploads et les index.

## Sauvegarde minimale recommandee

Avant toute operation critique:

```bash
cd "$HOME/chatfleet-infra"
docker compose ps
docker compose exec mongo mongodump \
  --username "$MONGO_ROOT_USER" \
  --password "$MONGO_ROOT_PASSWORD" \
  --authenticationDatabase admin \
  --archive=/tmp/chatfleet.archive
docker cp "$(docker compose ps -q mongo)":/tmp/chatfleet.archive ./chatfleet.archive
```

Sauvegarder aussi les volumes `chatfleet_uploads` et `chatfleet_index` si l'objectif est une restauration complete sans reindexation.

