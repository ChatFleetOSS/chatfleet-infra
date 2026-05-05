# 01 - Synthese executive technique

## Objectif de la plateforme

ChatFleet est une plateforme de chat documentaire multi-RAG. Elle permet a une organisation de creer plusieurs bases de connaissance, de controler l'acces utilisateur, d'indexer des documents et d'exposer une interface de chat fondee sur les extraits recuperes.

La livraison stable actuelle ajoute deux capacites majeures:

- ingestion OpenOffice / OpenDocument: `ODT`, `ODS`, `ODP`;
- prompt systeme RAG configurable par assistant, avec garde-fou backend non modifiable.

## Vue d'ensemble

| Axe | Etat livre |
| --- | --- |
| Backend | API FastAPI Python, MongoDB, FAISS, embeddings, jobs en memoire |
| Frontend | Next.js 15, React 19, UI admin et chat, validation Zod des reponses |
| Infra | Docker Compose, Caddy, MongoDB, installateur public `curl | bash` |
| CI/CD | GitHub Actions, build Docker, Trivy, Gitleaks, SBOM, Cosign, GHCR |
| Securite | JWT fort obligatoire, roles admin/user, RAG prive/public, uploads securises |
| Observabilite | Healthcheck API, build-info Web, correlation id, logs applicatifs |

## Releases incluses

### API `v0.1.17`

- Ajout de l'ingestion OpenDocument.
- Formats supportes: `ODT`, `ODS`, `ODP`.
- Extraction texte via parsers Python, sans shell-out vers une suite bureautique.
- Validation des packages OpenDocument comme conteneurs ZIP.

### Web `v0.1.19`

- Ajout des extensions OpenDocument dans l'interface d'upload admin.
- Le workflow RAG accepte `PDF`, `DOCX`, `TXT`, `ODT`, `ODS`, `ODP`.

### API `v0.1.18`

- Ajout du prompt systeme configurable par RAG.
- Extension des contrats `POST /api/rag`, `GET /api/admin/rag`, `PATCH /api/admin/rag`.
- Renforcement de la chaine de prompt:
  - politique RAG non modifiable;
  - prompt admin traite comme consignes de tonalite et de format;
  - historique et contexte marques comme donnees non fiables;
  - messages `system` fournis par le client ignores dans l'historique.

### Web `v0.1.20`

- Ajout de l'edition du prompt RAG dans l'admin.
- Ajout du prompt au formulaire de creation RAG.
- Ajout de l'action de reinitialisation vers le prompt par defaut.
- Ajout de feedback visuel pendant et apres l'enregistrement.

## Conditions de production

Pour un environnement client, les conditions suivantes sont requises:

- Docker et Docker Compose v2 disponibles;
- port `8080` libre ou adaptation Caddy/Compose;
- `JWT_SECRET` fort genere par l'installateur ou defini par l'operateur;
- acces reseau a `ghcr.io/chatfleetoss/*`;
- configuration LLM dans l'admin ou via variable `OPENAI_API_KEY`;
- sauvegarde reguliere des volumes Docker `mongo_data`, `chatfleet_index`, `chatfleet_uploads`.

## Limites connues

- Les jobs backend sont geres en memoire dans le processus API. Un redemarrage API interrompt le suivi de jobs en cours.
- Le schema de citation expose un champ `pages`; pour `ODT`, ce champ represente des unites d'extraction, pas des pages physiques.
- Les scans Trivy, Gitleaks et SBOM existent dans les pipelines mais certains sont encore non bloquants selon les workflows.
- Le stockage de la cle API runtime est chiffre si `CONFIG_MASTER_KEY` est fournie; sinon il est encode en base64, ce qui ne doit pas etre considere comme un chiffrement fort.
- L'installateur expose par defaut HTTP sur `:8080`. Le TLS necessite une configuration Caddy adaptee.

