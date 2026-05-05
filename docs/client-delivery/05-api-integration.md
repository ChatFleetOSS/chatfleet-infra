# 05 - Contrats API et integration

## Conventions

- Base URL via Caddy: `http://<host>:8080/api`
- Base URL API directe en dev: `http://localhost:8000/api`
- Authentification: `Authorization: Bearer <jwt>`
- Format erreur backend: enveloppe avec `error.code`, `error.message`, `corr_id`
- Les reponses de succes applicatives incluent un `corr_id`

## Authentification

| Methode | Endpoint | Acces | Description |
| --- | --- | --- | --- |
| `POST` | `/api/auth/register` | Public | Cree un utilisateur et retourne JWT. |
| `POST` | `/api/auth/login` | Public | Authentifie et retourne JWT. |
| `GET` | `/api/auth/me` | Auth | Retourne l'utilisateur courant. |

Exemple login:

```bash
curl -fsS http://localhost:8080/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"user@example.com","password":"secret"}'
```

## Endpoints systeme

| Methode | Endpoint | Acces | Description |
| --- | --- | --- | --- |
| `GET` | `/api/health` | Public | Sante API, Mongo, repertoires de stockage, version API. |
| `GET` | `/api/openapi.json` | Public | Schema OpenAPI FastAPI. |
| `GET` | `/api/admin/config` | Admin | Configuration effective: modeles, repertoires, limite upload. |

## Utilisateurs admin

| Methode | Endpoint | Description |
| --- | --- | --- |
| `GET` | `/api/admin/users?limit=50&cursor=...` | Liste paginee utilisateurs. |
| `POST` | `/api/admin/users` | Cree un utilisateur. |

## RAG

| Methode | Endpoint | Acces | Description |
| --- | --- | --- | --- |
| `GET` | `/api/rag/list` | Auth | Liste les RAG accessibles, plus RAG publics. |
| `GET` | `/api/admin/rag/list` | Admin | Liste tous les RAG. |
| `POST` | `/api/rag` | Admin | Cree un RAG. |
| `GET` | `/api/admin/rag?rag_slug=<slug>` | Admin | Detail admin, incluant le prompt systeme effectif. |
| `PATCH` | `/api/admin/rag` | Admin | Met a jour nom, description, visibilite, prompt systeme. |
| `POST` | `/api/rag/delete` | Admin | Supprime un RAG apres confirmation. |

Creation RAG:

```json
{
  "slug": "demo-saint-jo",
  "name": "Demo Saint-Jo",
  "description": "Base documentaire",
  "visibility": "private",
  "system_prompt": "Reponds en francais, de maniere concise et factuelle."
}
```

Regles:

- `slug`: `^[a-z0-9]+(?:-[a-z0-9]+)*$`, max 80 caracteres;
- `visibility`: `private` ou `public`;
- `system_prompt`: optionnel, max 4000 caracteres;
- prompt vide ou absent: prompt RAG par defaut.

## Upload et indexation

| Methode | Endpoint | Description |
| --- | --- | --- |
| `POST` | `/api/rag/upload` | Upload multipart, retourne `job_id`. |
| `GET` | `/api/jobs/{job_id}` | Polling statut job. |
| `GET` | `/api/rag/docs?rag_slug=<slug>` | Liste documents et statuts. |
| `GET` | `/api/rag/index/status?rag_slug=<slug>` | Etat index. |
| `POST` | `/api/rag/rebuild` | Rebuild index. |
| `POST` | `/api/rag/reset` | Reset documents/index en gardant le RAG. |

Upload:

```bash
curl -fsS http://localhost:8080/api/rag/upload \
  -H "Authorization: Bearer $JWT" \
  -F "rag_slug=demo-saint-jo" \
  -F "files=@contrat.odt" \
  -F "files=@budget.ods"
```

Formats supportes:

- `PDF`
- `DOCX`
- `TXT`
- `ODT`
- `ODS`
- `ODP`

## Chat

| Methode | Endpoint | Acces | Description |
| --- | --- | --- | --- |
| `POST` | `/api/chat` | Auth + acces RAG | Reponse JSON complete. |
| `POST` | `/api/chat/stream` | Auth + acces RAG | Streaming SSE. |
| `POST` | `/api/public/chat` | Public, RAG public | Reponse JSON complete. |
| `POST` | `/api/public/chat/stream` | Public, RAG public | Streaming SSE. |

Payload:

```json
{
  "rag_slug": "demo-saint-jo",
  "messages": [
    {"role": "user", "content": "Que dit le document sur les delais ?"}
  ],
  "opts": {
    "top_k": 6,
    "temperature": 0.2,
    "max_tokens": 500
  }
}
```

Contraintes:

- `messages` doit contenir au moins un message;
- le dernier message doit etre `role=user`;
- les messages `system` envoyes par le client sont ignores dans l'historique pour limiter les injections.

SSE:

1. `ready`
2. `chunk`
3. `citations`
4. `done`
5. `ping`

## Configuration LLM admin

| Methode | Endpoint | Description |
| --- | --- | --- |
| `GET` | `/api/admin/llm/config` | Lit la config runtime. |
| `POST` | `/api/admin/llm/config/test` | Teste provider chat. |
| `PUT` | `/api/admin/llm/config` | Sauvegarde provider, key, models, defaults. |
| `POST` | `/api/admin/llm/config/models` | Decouvre les modeles. |
| `POST` | `/api/admin/llm/config/test-embed` | Teste les embeddings. |

Providers:

- `openai` pour Chat Completions et embeddings OpenAI;
- `vllm` pour un endpoint compatible OpenAI;
- `local` pour embeddings via SentenceTransformers, force quand `provider=vllm`.

## Endpoints publics

| Methode | Endpoint | Description |
| --- | --- | --- |
| `GET` | `/api/public/rag/list` | Liste les RAG publics. |
| `GET` | `/api/public/rag/docs?rag_slug=<slug>` | Documents d'un RAG public. |
| `POST` | `/api/public/chat` | Chat public. |
| `POST` | `/api/public/chat/stream` | Chat public SSE. |

Un RAG doit avoir `visibility=public` pour etre expose.

## Snapshot des routes exposees

Cette liste a ete verifiee par introspection FastAPI avec l'application locale:

```text
GET /api/admin/config
GET /api/admin/llm/config
PUT /api/admin/llm/config
POST /api/admin/llm/config/models
POST /api/admin/llm/config/test
POST /api/admin/llm/config/test-embed
GET /api/admin/rag
PATCH /api/admin/rag
GET /api/admin/rag/list
GET /api/admin/users
POST /api/admin/users
POST /api/auth/login
GET /api/auth/me
POST /api/auth/register
POST /api/chat
POST /api/chat/stream
GET /api/health
GET /api/jobs/{job_id}
GET /api/openapi.json
POST /api/public/chat
POST /api/public/chat/stream
GET /api/public/rag/docs
GET /api/public/rag/list
POST /api/rag
POST /api/rag/delete
GET /api/rag/docs
GET /api/rag/index/status
GET /api/rag/list
POST /api/rag/rebuild
POST /api/rag/reset
POST /api/rag/upload
GET /api/rag/users
POST /api/rag/users/add
POST /api/rag/users/remove
```
