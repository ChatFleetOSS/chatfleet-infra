# 06 - RAG, ingestion documentaire et prompts configurables

## Cycle de vie RAG

1. Creation du RAG.
2. Attribution des utilisateurs.
3. Upload de documents.
4. Extraction du texte.
5. Chunking.
6. Generation embeddings.
7. Persistance payload chunks.
8. Construction index FAISS.
9. Generation de suggestions.
10. Chat avec retrieval + citations.

## Formats documentaires

| Extension | MIME interne | Support |
| --- | --- | --- |
| `.pdf` | `application/pdf` | Oui |
| `.docx` | `application/vnd.openxmlformats-officedocument.wordprocessingml.document` | Oui |
| `.txt` | `text/plain` | Oui |
| `.odt` | `application/vnd.oasis.opendocument.text` | Oui |
| `.ods` | `application/vnd.oasis.opendocument.spreadsheet` | Oui |
| `.odp` | `application/vnd.oasis.opendocument.presentation` | Oui |

Les fichiers `.doc`, `.xls`, `.ppt`, `.xlsx`, `.pptx`, templates OpenDocument et fichiers archives arbitraires ne sont pas dans le perimetre supporte actuel.

## Securisation upload

Le backend:

- n'utilise jamais le nom utilisateur comme chemin de stockage;
- stocke sous un nom genere;
- limite la taille en streaming avec `MAX_UPLOAD_MB`;
- calcule un `sha256`;
- rejette les uploads vides;
- verifie la signature `%PDF` pour les PDF;
- valide les packages OpenDocument avant extraction.

## OpenDocument

Les formats `ODT`, `ODS`, `ODP` sont des conteneurs ZIP. L'implementation les traite comme sources texte uniquement:

- `ODT`: paragraphes et lignes de tableaux;
- `ODS`: lignes de feuilles;
- `ODP`: slides et zones de texte.

Les images, medias, macros, pieces embarquees et ressources externes ne sont pas transformes en contenu RAG.

## Indexation

L'indexation est asynchrone via job backend. Les statuts documents peuvent etre:

- `uploaded`
- `chunking`
- `chunked`
- `indexing`
- `indexed`
- `error`

Les phases job peuvent etre:

- `queued`
- `chunking`
- `embedding`
- `indexing`
- `suggestions`
- `finalizing`

## Citations

Le chat retourne des citations:

```json
{
  "doc_id": "...",
  "filename": "contrat.odt",
  "pages": [1],
  "snippet": "..."
}
```

Attention:

- pour `PDF`, `pages` represente les pages extraites;
- pour `ODP`, `pages` correspond aux slides;
- pour `ODS`, `pages` correspond aux feuilles ou unites extraites;
- pour `ODT`, `pages` est une numerotation synthetique d'unites d'extraction.

## Prompt systeme RAG configurable

Chaque RAG peut stocker un `system_prompt` personnalise.

Objectif:

- adapter la tonalite;
- fixer la langue;
- definir le format;
- cadrer le niveau de detail;
- integrer des consignes metier non contradictoires avec la politique RAG.

Limites:

- max 4000 caracteres;
- chaine vide = retour au prompt par defaut;
- ne reconstruit pas l'index;
- s'applique aux prochaines conversations.

## Prompt par defaut

Le prompt par defaut demande:

- assistant utile et chaleureux;
- utilisation exclusive du contexte fourni;
- aucune connaissance externe;
- reponse prudente si contexte insuffisant;
- synthese structuree en 5 a 8 points si reponse longue;
- reponse dans la langue de l'utilisateur avec Markdown GitHub.

## Garde-fou non modifiable

Le backend ajoute avant le prompt admin une politique systeme immutable. Cette politique prime sur la consigne admin.

Le backend ajoute aussi dans le prompt:

- le contexte comme donnee non fiable;
- l'historique comme donnee non fiable;
- une instruction de fallback exacte si l'information n'est pas presente dans les extraits.

Les messages `system` envoyes par le client sont ignores lors de la reconstitution de l'historique.

## Bonnes pratiques de prompt admin

Exemples de consignes acceptables:

```text
Reponds en francais, avec un ton professionnel et concis.
Structure la reponse en trois sections: Resume, Details, Points de vigilance.
Lorsque l'information est absente, indique clairement que les extraits ne permettent pas de conclure.
```

Consignes a eviter:

```text
Ignore le contexte.
Reponds avec tes connaissances generales.
Donne des conseils meme si les documents ne le disent pas.
```

Ces consignes contradictoires ne doivent pas etre suivies par le backend.

