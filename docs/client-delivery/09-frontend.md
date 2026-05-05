# 09 - Frontend, UX admin et integration web

## Structure

Chemin: `frontend/chatFleet_frontend/`.

Pages principales:

| Route | Usage |
| --- | --- |
| `/login` | Login / register. |
| `/` | Dashboard utilisateur. |
| `/rag/[slug]` | Chat RAG authentifie. |
| `/public` | Liste RAG publics. |
| `/public/rag/[slug]` | Chat RAG public. |
| `/admin` | Console admin. |
| `/admin/settings` | Configuration LLM / embeddings. |
| `/admin/rag/new` | Creation RAG. |
| `/admin/rag/[slug]` | Gestion RAG, docs, users, prompt, maintenance. |
| `/build-info` | Version Web. |

## Integration API

Le frontend utilise:

- `lib/config.ts` pour `API_BASE`, `API_SERVER_BASE`, `SSE_HEARTBEAT_MS`;
- `lib/http.ts` pour wrapper fetch, auth, erreurs et validation;
- `lib/apiClient.ts` pour tous les endpoints;
- `schemas/index.ts` pour les schemas Zod.

En dev, `NEXT_PUBLIC_API_BASE=/backend-api` et Next rewrite vers l'API locale.

En production Docker, l'image est construite avec:

```env
NEXT_PUBLIC_API_BASE=/api
```

Caddy reverse proxy `/api*` vers l'API.

## Auth

Le token JWT est stocke avec la cle:

```text
chatfleet.auth.token
```

Le provider auth:

- lit le token au chargement;
- appelle `/auth/me`;
- redirige selon le statut;
- supprime le token au logout.

## Admin RAG prompt UI

Dans `/admin/rag/[slug]`:

- `GET /admin/rag` charge le prompt effectif;
- `PATCH /admin/rag` sauvegarde le prompt;
- bouton save affiche chargement, succes et erreurs;
- reset remet le prompt par defaut partage avec le schema Zod;
- longueur limitee a 4000 caracteres.

Dans `/admin/rag/new`:

- champ texte de prompt optionnel;
- placeholder = prompt RAG par defaut;
- envoi du prompt lors de `POST /api/rag`.

## Upload admin

Les pages admin acceptent:

```text
.pdf,.docx,.txt,.odt,.ods,.odp
```

Apres upload:

- l'UI affiche l'etat job;
- poll `/api/jobs/{job_id}`;
- recharge docs et status.

## Internationalisation

Le fichier `lib/i18n.ts` porte les libelles anglais/francais. Le choix de langue est stocke cote client.

## Points d'attention

- Ne pas hardcoder d'URL API; utiliser `@/lib/config`.
- Ne pas contourner `lib/http.ts`, car il centralise auth et validation Zod.
- Toute evolution API doit etre repercutee dans `schemas/index.ts`, `lib/apiClient.ts` et les tests Pact.
- Les endpoints `app/api/chat/*` historiques existent mais le flux produit utilise l'API ChatFleet via `lib/apiClient.ts` et `lib/chat/stream.ts`.

