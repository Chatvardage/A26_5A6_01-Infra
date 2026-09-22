# A26_5A6_01-Infra — Chatvardage C2

Infrastructure Docker du Contrôle 2. Ce dépôt fournit **PostgreSQL, Redis, les bases logiques, les utilisateurs SQL, les volumes et le réseau Docker**. Il ne crée aucune table métier : chaque microservice est propriétaire de son schéma et de ses migrations.


## Démarrage
Prérequis : Docker + Docker Compose, et **tous les dépôts clonés côte à côte** dans un même dossier parent. Le `docker-compose.yml` construit les microservices depuis des chemins relatifs (`../A26_5A6_01-Authentification`, `../A26_5A6_01-Room-Service`, etc.) : si un dépôt manque, `docker compose up --build` échoue.

```text
Chatvardage/
├── A26_5A6_01-Infra/                 # ce dépôt (lancer docker compose ici)
├── A26_5A6_01-Authentification/
├── A26_5A6_01-Room-Service/
├── A26_5A6_01-Message-Service/
├── A26_5A6_01-User-Config-Service/
└── A26_5A6_01-Serveur-API/
```

Le Compose orchestre Auth, Room, Message, User-Config et Serveur-API avec leurs healthchecks avant d'exposer le Gateway sur le port `3000`.

```bash
cp .env.example .env
docker compose up --build -d
docker compose ps
```

Au premier démarrage, PostgreSQL crée automatiquement :
- `chatvardage_auth`, propriétaire `auth_service`
- `chatvardage_rooms`, propriétaire `room_service`
- `chatvardage_messages`, propriétaire `message_service`
- `chatvardage_config`, propriétaire `config_service`

Les bases sont volontairement **vides au départ**. Les tables sont créées par les migrations du service concerné (Prisma ou l'outil de migration choisi par ce service).

## Connexions
> ⚠️ Les identifiants ci-dessous (et ceux de `.env.example`) sont réservés au développement local. Ne jamais les réutiliser dans un environnement partagé ou de production.

Depuis un service lancé **dans Docker** :
- Auth : `postgresql://auth_service:auth_service_dev@postgres:5432/chatvardage_auth`
- Room : `postgresql://room_service:room_service_dev@postgres:5432/chatvardage_rooms`
- Message : `postgresql://message_service:message_service_dev@postgres:5432/chatvardage_messages`
- Config : `postgresql://config_service:config_service_dev@postgres:5432/chatvardage_config`
- Redis : `redis://:chatvardage_redis_dev@redis:6379`

Tous les ports publiés (PostgreSQL `5432`, Redis `6379`, Adminer `8080`, Gateway `3000`, Auth `3001`, Room `3003`, Message `3004`, User-Config `3005`) sont liés à `127.0.0.1` uniquement : ils restent accessibles aux outils locaux, mais ne sont pas exposés aux autres machines du réseau.

Depuis un service lancé **sur la machine hôte**, remplacer `postgres` par `localhost`. Exemple Room-Service :

```env
DATABASE_URL="postgresql://room_service:room_service_dev@localhost:5432/chatvardage_rooms?schema=public"
```

## Tester avec Room-Service
```bash
# 1. Dans Infra
docker compose up -d
docker compose ps

# 2. Dans Room-Service
npx prisma generate
npx prisma migrate deploy
npm run start:dev
```

`prisma migrate deploy` doit créer les tables Rooms dans une base initialement vide. Infra ne doit jamais précréer `Room`, `RoomMember` ou `RoomInvitation`.

## Tester avec Authentification
```bash
docker compose up -d
curl http://localhost:3001/health
# Ensuite, vous pouvez tester les endpoints d'authentification avec Postman ou curl (voir README du service Authentification).
```


## Tester la stack backend complète

```bash
docker compose up --build -d
docker compose ps
curl http://localhost:3000/api/health
curl http://localhost:3000/api/health/upstreams
```

Le second endpoint doit rapporter `auth`, `room`, `message` et `userConfig` à `ok` lorsque toute la stack backend est prête.

## Réinitialiser l'environnement
```bash
./scripts/reset.sh
# Sans confirmation interactive (CI, scripts) :
./scripts/reset.sh -y
```
Cela supprime les volumes PostgreSQL/Redis et recrée les quatre bases vides. Les migrations des microservices doivent ensuite être réappliquées.

## Architecture des repos
- Frontend : Electron + ChatGateway réel
- Serveur-API : Gateway HTTP/WebSocket
- Authentification : utilisateurs/auth/rôles + migrations Auth
- Room-Service : salons/membres/invitations + migrations Rooms
- Message-Service : DM/historique/temps réel + migrations Messages
- User-Config-Service : alias/thème/préférences + migrations Config
- Dashboard : interface d'administration / AdminJS
- Infra : PostgreSQL, Redis, Docker Compose, réseau, volumes et orchestration

## Règle de propriété des données
**Infra crée les bases et les comptes SQL. Les microservices créent et font évoluer leurs tables.** Il ne faut pas dupliquer les schémas ou migrations dans Infra.

Pour le C2, PostgreSQL reste la source de vérité. Redis/WebSocket servent au temps réel des messages privés après une écriture réussie en base. Les messages de salons restent hors de la persistance C2.


## Authentification intégrée

Le Compose global démarre `auth-service` (3001) avant `room-service`, `message-service` et `user-config-service`, puis démarre `serveur-api` (3000) lorsque les quatre services sont sains. Rooms et Messages reçoivent le JWT du client puis valident la session courante auprès de `http://auth-service:3001/api/auth/me`. Pour User-Config, le Gateway valide lui-même la session auprès d'Auth et transmet uniquement un `x-user-id` de confiance. Le rôle reste la propriété du service Auth et n'est pas recopié dans le JWT.

Pour l’environnement Docker local du contrôle, `room-service` est explicitement lancé avec `NODE_ENV=development`. Cela autorise l’URL HTTP interne `http://auth-service:3001` sur le réseau Docker privé. En production réelle, Room-Service conserve sa validation qui exige HTTPS. Le délai Room-Service est fourni avec `AUTH_TIMEOUT_MS`; Message-Service utilise `AUTH_SERVICE_TIMEOUT_MS`.

### Variables CORS
Deux variables coexistent volontairement dans `.env`, car chaque service lit son propre nom :
- `CORS_ALLOWED_ORIGINS` : Auth-Service (Rust);
- `CORS_ORIGINS` : Message-Service, User-Config-Service et Serveur-API (Node).

Les garder synchronisées : si une seule est renseignée, les autres services retombent sur leur valeur par défaut sans message d'erreur.

Au premier démarrage sur un volume vide, Infra crée les bases/rôles PostgreSQL. Chaque service exécute ensuite ses propres migrations au démarrage de son conteneur.

## Adminer (administration BD, dev uniquement)
Le service `adminer` est un outil générique d'inspection de PostgreSQL pour le développement. **Ce n'est pas le Dashboard** : le Dashboard (AdminJS) vit dans le dépôt `A26_5A6_01-Dashboard` et n'est pas encore orchestré par ce Compose.

> ⚠️ Les identifiants ci-dessous sont ceux du superutilisateur PostgreSQL de développement (`POSTGRES_SUPERUSER`/`POSTGRES_SUPERPASS`).

- Se rendre sur http://localhost:8080
- Système : « PostgreSQL »
- Serveur : `postgres`
- Utilisateur : `postgres`
- Mot de passe : `postgres`
- Base : sélectionner la base souhaitée dans le menu déroulant (ou laisser vide pour voir toutes les bases)
