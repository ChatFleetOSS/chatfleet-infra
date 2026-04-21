# ChatFleet - Installation Developer sur une Nouvelle Machine

Ce guide s'adresse a un developpeur ou un power user qui veut installer une instance ChatFleet fonctionnelle sur une machine neuve, sans supposer qu'une etape "evidente" a deja ete faite.

Le chemin recommande passe par `chatfleet-infra`. C'est le point d'entree officiel pour :
- installer la stack complete `Mongo + API + Web + Caddy`
- choisir une paire de versions coherente
- verifier les versions effectivement servies
- eviter le drift entre infra, backend et frontend

Ce guide couvre :
- l'installation initiale
- le choix entre `stable` et `edge`
- la creation du premier admin
- la verification post-install
- l'upgrade sans perte de donnees
- les cas de reinstallation sur une machine de dev

## 1. Ce que l'installation fait exactement

Le script d'installation :

1. clone `chatfleet-infra` dans `"$HOME/chatfleet-infra"` par defaut
2. cree un fichier `.env` avec les secrets et les tags d'images
3. choisit la paire API/Web a deployer depuis un canal (`stable` par defaut, `edge` si demande)
4. lance `docker compose`
5. attend que l'API reponde
6. verifie que les versions servies correspondent bien a celles demandees

Expose ensuite :
- UI web : `http://localhost:8080`
- health API : `http://localhost:8080/api/health`
- build info web : `http://localhost:8080/build-info`

Par defaut :
- les donnees persistent dans les volumes Docker
- le code infra est localement dans `"$HOME/chatfleet-infra"`
- les secrets sont dans `"$HOME/chatfleet-infra/.env"`

## 2. Prerequis exacts

Avant de lancer l'installation, il faut avoir :

- `git`
- `curl`
- `python3`
- Docker avec Compose v2
- un acces reseau sortant vers `github.com` et `ghcr.io`
- plusieurs Go d'espace disque libre pour les images Docker et les volumes
- le port `8080` libre sur la machine si vous gardez la configuration par defaut

Verification recommandee :

```bash
git --version
curl --version
python3 --version
docker --version
docker compose version
```

Si une de ces commandes echoue, il faut corriger avant de continuer.

Verification utile avant install :

```bash
docker info >/dev/null
lsof -nP -iTCP:8080 -sTCP:LISTEN || true
df -h
```

Interpretation :
- `docker info` doit repondre
- rien d'important ne doit deja occuper `:8080`
- il faut avoir assez de place disque pour le premier pull Docker

## 3. Preparation de la machine

### macOS

1. Installer Docker Desktop.
2. Ouvrir Docker Desktop.
3. Attendre qu'il soit completement demarre.
4. Verifier :

```bash
docker info >/dev/null
docker compose version
```

Si `docker info` echoue, ne pas lancer ChatFleet tout de suite. Attendre que Docker Desktop soit vraiment pret.

### Linux

Deux options existent.

Option A : Docker est deja installe

1. Verifier :

```bash
docker info >/dev/null
docker compose version
```

2. Si `docker info` echoue pour une question de permissions, il faut corriger le groupe Docker ou lancer avec sudo.

Option B : Docker n'est pas encore installe

L'installateur peut essayer de l'installer automatiquement sur Debian/Ubuntu avec `INSTALL_DOCKER=1`.

Important :
- cette installation peut demander `sudo`
- il est possible que le groupe Docker ne soit pas applique immediatement a la session courante
- dans ce cas, le script peut retenter certaines commandes avec `sudo`

## 4. Choisir le bon canal avant install

Deux modes sont utiles.

### `stable`

C'est le mode par defaut.

Utiliser `stable` si vous voulez :
- une machine neuve fiable
- une paire API/Web explicitement promue
- le comportement recommande pour la plupart des installs

### `edge`

Utiliser `edge` si vous voulez :
- tester le dernier `main` backend/frontend
- valider des changements avant promotion en `stable`
- travailler en mode integration continue

`edge` est utile pour un developpeur, mais ce n'est pas le canal le plus conservateur.

## 5. Commande d'installation recommande

### Installation standard en `stable`

```bash
curl -fsSL "https://raw.githubusercontent.com/ChatFleetOSS/chatfleet-infra/main/install.sh?$(date +%s)" | bash
```

Note :
- le premier `docker compose pull` peut etre long sur une machine neuve
- ne pas interrompre la commande tant que les images sont en cours de telechargement
- la duree depend fortement du reseau et du cache Docker deja present

### Installation en `edge`

```bash
curl -fsSL "https://raw.githubusercontent.com/ChatFleetOSS/chatfleet-infra/main/install.sh?$(date +%s)" | CHANNEL=edge bash
```

Equivalent acceptable :

```bash
curl -fsSL "https://raw.githubusercontent.com/ChatFleetOSS/chatfleet-infra/main/install.sh?$(date +%s)" | EDGE=1 bash
```

### Installation avec creation du premier admin

Mode interactif :

```bash
curl -fsSL "https://raw.githubusercontent.com/ChatFleetOSS/chatfleet-infra/main/install.sh?$(date +%s)" | CREATE_ADMIN=1 bash
```

Mode non interactif :

```bash
curl -fsSL "https://raw.githubusercontent.com/ChatFleetOSS/chatfleet-infra/main/install.sh?$(date +%s)" | CREATE_ADMIN=1 ADMIN_EMAIL=you@example.com bash
```

### Installation `edge` + admin

```bash
curl -fsSL "https://raw.githubusercontent.com/ChatFleetOSS/chatfleet-infra/main/install.sh?$(date +%s)" | CHANNEL=edge CREATE_ADMIN=1 ADMIN_EMAIL=you@example.com bash
```

## 6. Ce qu'il se passe pendant l'installation

Pendant l'execution, le script :

1. verifie les prerequis systeme
2. installe Docker automatiquement si vous etes sur Debian/Ubuntu et que `INSTALL_DOCKER=1` est fourni
3. clone ou met a jour `chatfleet-infra`
4. cree `.env` si besoin
5. choisit `CHATFLEET_CHANNEL`, `API_TAG` et `WEB_TAG`
6. lance `docker compose pull`
7. lance `docker compose up -d --remove-orphans`
8. attend la reponse de `http://localhost:8080/api/health`
9. verifie que l'API et le web exposes correspondent bien aux tags attendus
10. affiche les URLs finales

Si `CREATE_ADMIN=1` est actif :

1. le script demande ou lit `ADMIN_EMAIL`
2. il cree une intention de promotion admin
3. le premier login reussi avec cet email bascule immediatement ce compte en admin

## 7. Verifications immediates apres installation

Une fois le script termine, verifier explicitement :

```bash
curl -fsS http://localhost:8080/api/health
curl -fsS http://localhost:8080/build-info
```

Verifier aussi l'etat Docker :

```bash
cd "$HOME/chatfleet-infra"
docker compose ps
```

Les services attendus doivent etre presents et demarres :
- `mongo`
- `mongo-init`
- `api`
- `web`
- `caddy`

Verifier que le repertoire existe :

```bash
ls -la "$HOME/chatfleet-infra"
ls -la "$HOME/chatfleet-infra/.env"
```

## 8. Premiere connexion dans l'UI

1. Ouvrir `http://localhost:8080`
2. Aller sur `/login`
3. Creer un compte ou se connecter

Si `CREATE_ADMIN=1` et `ADMIN_EMAIL=...` ont ete utilises :
- connectez-vous avec exactement cet email
- le compte sera promu admin au premier login reussi

Verification rapide :
- l'UI charge
- le login fonctionne
- l'espace admin devient visible si l'utilisateur a ete promu

## 9. Fichiers et repertoires importants

Repertoire principal :

```bash
$HOME/chatfleet-infra
```

Fichiers utiles :
- `docker-compose.yml` : stack Docker
- `.env` : secrets, tags et configuration locale
- `upgrade.sh` : upgrade sans perte de donnees
- `cleanup.sh` : nettoyage local
- `uninstall.sh` : suppression de l'installation
- `channels/stable.env` : paire par defaut
- `channels/edge.env` : paire `main`

Endpoints utiles :
- `http://localhost:8080`
- `http://localhost:8080/api/health`
- `http://localhost:8080/build-info`

## 10. Commandes utiles apres l'installation

Voir les logs :

```bash
cd "$HOME/chatfleet-infra"
docker compose logs --tail=200
```

Voir uniquement l'API :

```bash
cd "$HOME/chatfleet-infra"
docker compose logs --tail=200 api
```

Redemarrer la stack :

```bash
cd "$HOME/chatfleet-infra"
docker compose up -d --remove-orphans
```

Arreter la stack :

```bash
cd "$HOME/chatfleet-infra"
docker compose down
```

## 11. Upgrade sans perte de donnees

### Upgrade standard

```bash
$HOME/chatfleet-infra/upgrade.sh
```

### Upgrade vers `edge`

```bash
CHANNEL=edge $HOME/chatfleet-infra/upgrade.sh
```

### Upgrade vers une paire explicite

```bash
API_TAG=v0.x.y WEB_TAG=v0.x.z $HOME/chatfleet-infra/upgrade.sh
```

Ce script :
- relit le canal ou les tags
- fait `docker compose pull`
- relance la stack
- reverifie les versions servies

## 12. Cas special utile pour un developpeur

Si vous voulez une machine de dev pour tester les derniers `main` backend/frontend :

```bash
curl -fsSL "https://raw.githubusercontent.com/ChatFleetOSS/chatfleet-infra/main/install.sh?$(date +%s)" | CHANNEL=edge CREATE_ADMIN=1 ADMIN_EMAIL=you@example.com bash
```

Puis, pour vous remettre a jour plus tard :

```bash
CHANNEL=edge $HOME/chatfleet-infra/upgrade.sh
```

## 13. Reinstallation propre sur une machine de dev

### Cas A : vous voulez seulement reposer les conteneurs

```bash
cd "$HOME/chatfleet-infra"
docker compose down
docker compose up -d --remove-orphans
```

### Cas B : vous voulez reinstaller sans supprimer les donnees

1. garder `"$HOME/chatfleet-infra/.env"`
2. garder les volumes Docker
3. relancer l'installateur ou `upgrade.sh`

### Cas C : vous voulez repartir de zero

Attention : cela supprime l'installation locale et peut supprimer les donnees selon la methode choisie.

Retirer l'installation :

```bash
$HOME/chatfleet-infra/uninstall.sh
```

Si vous voulez aussi effacer les volumes Docker, verifier d'abord ce que vous faites puis supprimer explicitement les volumes lies a ChatFleet.

## 14. Problemes frequents

### `docker` n'est pas trouve

Installer Docker Desktop sur macOS, ou utiliser `INSTALL_DOCKER=1` sur Debian/Ubuntu.

### `docker compose` echoue par permission

Sur Linux :
- verifier `docker info`
- si besoin, utiliser `sudo`
- si Docker vient d'etre installe, ouvrir une nouvelle session shell

### L'API ne repond pas sur `http://localhost:8080/api/health`

Verifier :

```bash
cd "$HOME/chatfleet-infra"
docker compose ps
docker compose logs --tail=200 api
docker compose logs --tail=200 caddy
```

### Le navigateur ne charge pas l'UI

Verifier :

```bash
curl -fsS http://localhost:8080/build-info
```

Si cette commande repond, la stack web est en place et le probleme est souvent lie au navigateur, au port local ou a Caddy.

### Le compte admin n'apparait pas

Verifier :
- que `CREATE_ADMIN=1` a bien ete fourni
- que `ADMIN_EMAIL` est exactement le meme que l'email utilise au login
- que le login a bien reussi une premiere fois

## 15. Checklist courte de fin d'installation

Avant de considerer la machine "prete", verifier :

1. `docker compose ps` montre tous les services utiles demarres
2. `curl http://localhost:8080/api/health` repond
3. `curl http://localhost:8080/build-info` repond
4. l'UI charge sur `http://localhost:8080`
5. un login fonctionne
6. le compte admin est bien admin si vous avez utilise `CREATE_ADMIN=1`

## 16. Commande recommandee a copier-coller

Pour un developpeur qui veut une machine neuve avec les dernieres versions `main` et un admin des la premiere connexion :

```bash
curl -fsSL "https://raw.githubusercontent.com/ChatFleetOSS/chatfleet-infra/main/install.sh?$(date +%s)" | CHANNEL=edge CREATE_ADMIN=1 ADMIN_EMAIL=you@example.com bash
```

Pour un developpeur qui veut la voie la plus stable :

```bash
curl -fsSL "https://raw.githubusercontent.com/ChatFleetOSS/chatfleet-infra/main/install.sh?$(date +%s)" | CREATE_ADMIN=1 ADMIN_EMAIL=you@example.com bash
```
