# 07 - Securite, secrets et donnees

## Modele d'acces

Roles:

- `user`: acces aux RAG assignes et aux RAG publics;
- `admin`: acces a la console admin, creation RAG, users, LLM settings, ingestion, maintenance.

Mecanismes:

- JWT signe avec `JWT_SECRET`;
- `JWT_SECRET` faible ou absent bloque le demarrage backend;
- endpoints admin proteges par `require_admin`;
- endpoints user proteges par `get_current_user`;
- endpoints publics limites aux RAG `visibility=public`.

## Secrets

Secrets principaux:

- `JWT_SECRET`;
- `MONGO_ROOT_PASSWORD`;
- `MONGO_APP_PASSWORD`;
- `OPENAI_API_KEY`;
- config runtime LLM en base.

Regles:

- ne jamais committer `.env`;
- generer un secret JWT de 32 caracteres minimum;
- limiter les droits du compte Mongo applicatif a la base `chatfleet`;
- fournir `CONFIG_MASTER_KEY` en production si l'on utilise la configuration LLM runtime.

## Stockage cle LLM runtime

Le service `runtime_config.py` chiffre `api_key` avec Fernet si `CONFIG_MASTER_KEY` est fourni.

Sans `CONFIG_MASTER_KEY`, la cle est seulement encodee base64. Cette configuration est acceptable pour le developpement, pas pour une production client sensible.

Recommandation production:

```bash
CONFIG_MASTER_KEY=<fernet-key-ou-secret-fort>
```

Puis recreer le service API.

## Uploads

Protections implementees:

- allowlist d'extensions;
- stockage sous noms generes;
- limite taille en streaming;
- hash SHA-256;
- verification PDF minimale;
- validation OpenDocument;
- extraction via bibliotheques Python, sans execution de commande bureautique.

Risques residuels:

- absence de scan antivirus integre;
- extraction texte limitee, pas d'OCR image;
- pas de DLP integre;
- les documents publics deviennent consultables via endpoints publics si le RAG est marque `public`.

## RAG prompt injection

Protections implementees:

- politique systeme non modifiable;
- prompt admin place apres cette politique;
- contexte et historique marques comme non fiables;
- messages client `system` filtres;
- fallback quand le contexte est vide ou insuffisant.

Risques residuels:

- le modele LLM peut toujours etre influence par du texte malveillant dans les documents;
- les controles doivent etre completes par de la qualite documentaire et une revue des prompts admin;
- les reponses doivent etre presentees avec citations pour faciliter l'audit humain.

## Reseau

Par defaut:

- Caddy expose HTTP sur `:8080`;
- API et Web ne sont pas exposes directement hors reseau Compose;
- Caddy reverse proxy `/api*` vers API et le reste vers Web.

Headers Caddy:

- `X-Content-Type-Options: nosniff`;
- `Referrer-Policy: strict-origin-when-cross-origin`;
- CSP de base restrictive.

Production Internet:

- ajouter TLS Caddy avec domaine;
- revoir CSP selon ressources externes;
- ajouter rate limiting sur auth;
- ajouter sauvegardes chiffrees;
- restreindre l'acces serveur par firewall.

## CI securite

Les pipelines incluent:

- Trivy image scan;
- Gitleaks;
- SBOM Anchore/Syft;
- Cosign keyless signing;
- budgets de taille d'image.

Certains controles sont encore non bloquants. Pour une production durcie, les rendre bloquants apres burn-down des faux positifs.

