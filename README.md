# A26_5A6_01-Infra — Chatvardage C2

Infrastructure Docker du Contrôle 2. Ce dépôt fournit **PostgreSQL, Redis, les bases logiques, les utilisateurs SQL, les volumes et le réseau Docker**. Il ne crée aucune table métier : chaque microservice est propriétaire de son schéma et de ses migrations.


## Démarrage
Prérequis : Docker + Docker Compose uniquement.
Le healthcheck d’Auth-Service est défini dans son `Dockerfile`; Room-Service possède aussi un healthcheck dans ce Compose.

```bash
cp .env.example .env
docker compose up -d
docker compose ps
```

Au premier démarrage, PostgreSQL crée automatiquement :
- `chatvardage_auth`, propriétaire `auth_service`
- `chatvardage_rooms`, propriétaire `room_service`
- `chatvardage_messages`, propriétaire `message_service`
- `chatvardage_config`, propriétaire `config_service`

Les bases sont volontairement **vides au départ**. Les tables sont créées par les migrations du service concerné (Prisma ou l'outil de migration choisi par ce service).

## Connexions
Depuis un service lancé **dans Docker** :
- Auth : `postgresql://auth_service:auth_service_dev@postgres:5432/chatvardage_auth`
- Room : `postgresql://room_service:room_service_dev@postgres:5432/chatvardage_rooms`
- Message : `postgresql://message_service:message_service_dev@postgres:5432/chatvardage_messages`
- Config : `postgresql://config_service:config_service_dev@postgres:5432/chatvardage_config`
- Redis : `redis://:chatvardage_redis_dev@redis:6379`

Les ports PostgreSQL (`5432`) et Redis (`6379`) sont liés à `127.0.0.1` uniquement : ils restent accessibles aux outils locaux, mais ne sont pas exposés aux autres machines du réseau.

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

## Réinitialiser l'environnement
```bash
./scripts/reset.sh
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

Le Compose global démarre `auth-service` (3001) avant `room-service` et `message-service`. Rooms et Messages reçoivent le JWT du client puis valident la session courante auprès de `http://auth-service:3001/api/auth/me`. Le rôle reste la propriété du service Auth et n'est pas recopié dans le JWT.

Au premier démarrage sur un volume vide, Infra crée les bases/rôles PostgreSQL. Chaque service exécute ensuite ses propres migrations au démarrage de son conteneur.
