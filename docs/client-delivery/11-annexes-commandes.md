# 11 - Annexes: commandes et aide au diagnostic

## Connaitre le channel installe

```bash
cd "$HOME/chatfleet-infra"
grep -E '^(CHATFLEET_CHANNEL|API_TAG|WEB_TAG)=' .env
bash scripts/resolve-channel.sh
```

## Verifier les images publiques

```bash
docker manifest inspect ghcr.io/chatfleetoss/chatfleet-api:v0.1.18
docker manifest inspect ghcr.io/chatfleetoss/chatfleet-web:v0.1.20
```

## Logs

```bash
cd "$HOME/chatfleet-infra"
docker compose logs --tail=200 api
docker compose logs --tail=200 web
docker compose logs --tail=200 caddy
docker compose logs --tail=200 mongo
```

## Redemarrer un service

```bash
docker compose restart api
docker compose restart web
docker compose restart caddy
```

## Rebuild un RAG

```bash
curl -fsS http://localhost:8080/api/rag/rebuild \
  -H "Authorization: Bearer $JWT" \
  -H "Content-Type: application/json" \
  -d '{"rag_slug":"demo-saint-jo"}'
```

## Reset un RAG

```bash
curl -fsS http://localhost:8080/api/rag/reset \
  -H "Authorization: Bearer $JWT" \
  -H "Content-Type: application/json" \
  -d '{"rag_slug":"demo-saint-jo","confirm":true}'
```

## Supprimer un RAG

```bash
curl -fsS http://localhost:8080/api/rag/delete \
  -H "Authorization: Bearer $JWT" \
  -H "Content-Type: application/json" \
  -d '{"rag_slug":"demo-saint-jo","confirmation":"demo-saint-jo"}'
```

## Creer un RAG avec prompt

```bash
curl -fsS http://localhost:8080/api/rag \
  -H "Authorization: Bearer $JWT" \
  -H "Content-Type: application/json" \
  -d '{
    "slug": "demo-saint-jo",
    "name": "Demo Saint-Jo",
    "description": "Base documentaire de demonstration",
    "visibility": "private",
    "system_prompt": "Reponds en francais avec un ton professionnel, en trois points maximum."
  }'
```

## Mettre a jour le prompt

```bash
curl -fsS http://localhost:8080/api/admin/rag \
  -H "Authorization: Bearer $JWT" \
  -H "Content-Type: application/json" \
  -d '{
    "rag_slug": "demo-saint-jo",
    "system_prompt": "Reponds en francais, avec une synthese executive suivie des details utiles."
  }' \
  -X PATCH
```

## Upload OpenDocument

```bash
curl -fsS http://localhost:8080/api/rag/upload \
  -H "Authorization: Bearer $JWT" \
  -F "rag_slug=demo-saint-jo" \
  -F "files=@document.odt" \
  -F "files=@tableur.ods" \
  -F "files=@presentation.odp"
```

## Chat streaming avec curl

```bash
curl -N http://localhost:8080/api/chat/stream \
  -H "Authorization: Bearer $JWT" \
  -H "Content-Type: application/json" \
  -d '{
    "rag_slug": "demo-saint-jo",
    "messages": [
      {"role": "user", "content": "Resume les obligations principales."}
    ],
    "opts": {"top_k": 6, "temperature": 0.2, "max_tokens": 700}
  }'
```

## Promouvoir stable dans infra

```bash
cd chatfleet-infra
python3 scripts/promote_channel.py \
  --channel stable \
  --api-tag v0.1.18 \
  --web-tag v0.1.20
git diff -- channels/stable.env
```

