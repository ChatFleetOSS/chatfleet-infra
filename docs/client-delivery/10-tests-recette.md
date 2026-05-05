# 10 - Tests, recette et criteres d'acceptation

## Checks backend

```bash
cd backend
ruff check .
python -m compileall -q app main.py tests scripts
npm ci
npm run pact:all
```

Checks additionnels utiles:

```bash
python -m unittest tests/test_opendocument_ingestion_unit.py
python -m unittest tests/test_rag_system_prompt_unit.py
python -m unittest tests/test_suggestions_unit.py
mypy --ignore-missing-imports --no-strict-optional app
```

## Checks frontend

```bash
cd frontend/chatFleet_frontend
npm ci
npx tsc --noEmit
npm run build
npm run prettier
```

Note: le repo peut avoir des ecarts Prettier preexistants sur fichiers non touches; pour une PR, verifier au minimum les fichiers modifies.

## Checks infra

```bash
cd chatfleet-infra
bash scripts/resolve-channel.sh
python3 scripts/test_promotion_flow.py
python3 scripts/promote_channel.py --channel stable --api-tag v0.1.18 --web-tag v0.1.20 --verify-only
```

## Recette installation

```bash
INSTALL_DIR=/tmp/chatfleet-recette \
curl -fsSL "https://raw.githubusercontent.com/ChatFleetOSS/chatfleet-infra/main/install.sh?$(date +%s)" | bash
```

Valider:

```bash
curl -fsS http://localhost:8080/api/health
curl -fsS http://localhost:8080/build-info
```

## Recette fonctionnelle minimale

1. Creer ou promouvoir un admin.
2. Se connecter.
3. Configurer LLM dans Admin -> Settings.
4. Creer un RAG prive.
5. Renseigner un prompt systeme personnalise.
6. Uploader un `ODT`, un `ODS` ou un `ODP`.
7. Attendre job `done`.
8. Verifier documents `indexed`.
9. Poser une question couverte par les documents.
10. Verifier reponse avec citations.
11. Modifier le prompt pour imposer un format.
12. Reposer une question et verifier que la forme change sans sortir du contexte.
13. Passer le RAG en public.
14. Tester `/public/rag/<slug>`.

## Criteres d'acceptation

Installation:

- le stack demarre en moins de quelques minutes;
- `/api/health` retourne `ok`;
- `/build-info` retourne la version Web attendue;
- API et Web correspondent au channel stable.

RAG:

- creation RAG OK;
- upload multi-format OK;
- job consultable;
- erreurs documentaires visibles;
- rebuild et reset OK;
- suppression RAG supprime les references utilisateurs.

Prompt:

- prompt visible en admin;
- reset par defaut fonctionne;
- sauvegarde affiche un feedback visuel;
- prompt modifie influence tonalite/format;
- prompt contradictoire ne peut pas autoriser la connaissance externe.

Securite:

- endpoints admin refusent un user non admin;
- RAG prive non accessible publiquement;
- RAG public accessible sans JWT;
- JWT faible bloque demarrage.

CI/CD:

- release workflows verts;
- images GHCR multi-arch presentes;
- infra CI stable verte;
- GitHub Releases publiques documentees.

