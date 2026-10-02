# Chatvardage — User Config Service

Microservice de configuration utilisateur.

Ce dépôt contient uniquement le service responsable des préférences personnelles de chaque utilisateur : alias, avatar, thème, langue, statut de présence et mode de notification. L'authentification, les salons et les messages ne sont pas gérés par ce service.

## Technologies

- NestJS + TypeScript
- Prisma ORM
- PostgreSQL
- Swagger / OpenAPI
- Docker

## Responsabilités

Le service permet de :

- récupérer la configuration de l'utilisateur connecté (créée automatiquement avec des valeurs par défaut si elle n'existe pas encore);
- mettre à jour l'alias, le thème, la langue et le mode de notification;
- définir le statut de présence (en ligne / hors ligne) et l'horodatage de dernière activité;
- conserver ces préférences dans PostgreSQL, une ligne par utilisateur.

Le modèle retourné par l'API, utilisé par le client Electron comme source de vérité de ses préférences (voir « Intégration avec Chatvardage ») :

```ts
{
  type: 'configUtilisateur',
  idUtilisateur: string,
  alias: string | null,
  theme: 'sombre' | 'clair',
  langue: 'fr' | 'en',
  statutPresence: 'enLigne' | 'horsLigne',
  vuLaDerniereFois: string | null,
  modeNotification: 'systeme' | 'discret' | 'aucune',
  avatar: string | null // data URL base64 PNG/JPEG/WebP, ou null
}
```

## Authentification entre services

L'authentification est effectuée par le service **Authentification** et l'API Gateway.

Le User-Config-Service reçoit l'identité déjà validée dans l'en-tête interne,
accompagnée du secret partagé entre microservices :

```http
x-internal-token: <INTERNAL_SERVICE_TOKEN>
x-user-id: <id utilisateur>
```

`x-user-id` n'est cru que si `x-internal-token` est exact (comparaison en
temps constant) : sans lui, n'importe quel processus capable de joindre le
port 3005 pouvait lire ou modifier la configuration de n'importe qui. Sans
`INTERNAL_SERVICE_TOKEN` configuré, toutes les routes sauf `/api/health`
répondent 503 (échec fermé). Les deux en-têtes sont posés par l'API Gateway
après validation du JWT ; il retire ceux envoyés par le client. Ce service ne
doit de toute façon pas être exposé directement à Internet.

## Routes

Toutes les routes sont préfixées par `/api`.

| Méthode | Route                              | Description                                                                                        |
| ------- | ---------------------------------- | -------------------------------------------------------------------------------------------------- |
| GET     | `/api/config-utilisateur`          | Récupère la configuration de l'utilisateur connecté (créée avec des valeurs par défaut si absente) |
| GET     | `/api/config-utilisateur/publiques?ids=a,b` | Profils publics d'autres utilisateurs (alias, avatar, présence effective `actif`) ; `inclureAvatar=false` pour omettre les images |
| PATCH   | `/api/config-utilisateur`          | Met à jour l'alias, le thème, la langue, le mode de notification ou l'avatar                              |
| PUT     | `/api/config-utilisateur/presence` | Définit le statut de présence de l'utilisateur connecté                                            |
| DELETE  | `/api/internal/users/:userId`      | Compte supprimé (appelée par Authentification) : efface sa configuration. Réponse `{ supprime }`    |
| GET     | `/api/health`                      | Vérifie le service et PostgreSQL (seule route sans jeton interne)                                  |

Pour effacer l'alias, envoyez une chaîne vide ou composée uniquement d'espaces :
elle est persistée comme `null`.

## Installation locale

Prérequis : Node.js 22, et un PostgreSQL accessible sur `localhost:5432` (via Docker, voir plus bas).

`npx prisma migrate deploy` se connecte réellement à une base de données : il faut donc qu'un PostgreSQL tourne déjà **avec les identifiants attendus par `.env`** avant de le lancer. Deux façons d'obtenir ce PostgreSQL, à ne pas mélanger :

### Option A — PostgreSQL du dépôt `Infra` (recommandé)

C'est la base déjà provisionnée avec les vrais identifiants du service (`config_service` / `chatvardage_config`), celle utilisée par l'environnement d'équipe.

```bash
cd ../A26_5A6_01-Infra
docker compose up -d postgres
cd ../A26_5A6_01-User-Config-Service

npm install
cp .env.example .env
npx prisma generate
npx prisma migrate deploy
npm run start:dev
```

`.env.example` pointe déjà vers `postgresql://config_service:config_service_dev@localhost:5432/chatvardage_config` : ne pas modifier ces identifiants dans ce scénario, ils correspondent à ceux créés par `Infra`.

### Option B — PostgreSQL autonome (`compose.local.yml`)

Pour tester ce dépôt sans dépendre d'`Infra`, voir la section suivante. Ce PostgreSQL utilise des identifiants génériques différents (`chatvardage` / `chatvardage`) : si on l'utilise, `.env` doit être ajusté en conséquence (ou lancer directement `docker compose -f compose.local.yml up --build`, qui définit `DATABASE_URL` lui-même sans passer par `.env`).

**Erreur `P1001: Can't reach database server at localhost:5432`** : aucun PostgreSQL ne tourne encore (ou celui qui tourne n'a pas les mêmes identifiants que `.env`). Démarrer l'option A ou B ci-dessus avant de relancer `npx prisma migrate deploy`.

Le service écoute par défaut sur :

```text
http://localhost:3005
```

Swagger est disponible sur :

```text
http://localhost:3005/docs
```

## Lancement avec Docker pour tester ce dépôt seul

Le fichier `compose.local.yml` permet de tester le microservice indépendamment de l'infrastructure globale, avec son propre PostgreSQL jetable (identifiants génériques `chatvardage` / `chatvardage`, distincts de ceux d'`Infra`) :

```bash
docker compose -f compose.local.yml up --build
```

Il démarre :

- `user-config-service` sur le port `3005`;
- PostgreSQL sur le port `5432`.

Ne pas lancer ce PostgreSQL en même temps que celui d'`Infra` : les deux écoutent sur le port `5432` et entreraient en conflit.

Dans l'environnement complet, ce service est lancé par le `docker-compose.yml` global du dépôt `Infra`, avec les autres microservices.

## Variables d'environnement

```env
PORT=3005
CORS_ORIGINS=http://localhost:5173
# Même valeur que dans Serveur-API et Authentification.
INTERNAL_SERVICE_TOKEN=chatvardage_internal_dev
DATABASE_URL="postgresql://config_service:config_service_dev@localhost:5432/chatvardage_config?schema=public"
```

`CORS_ORIGINS` accepte une liste d'origines séparées par des virgules. Si elle
est absente, le service autorise uniquement `http://localhost:5173`.

### En production (`NODE_ENV=production`)

Le service **refuse de démarrer** si `INTERNAL_SERVICE_TOKEN` fait moins de 32 caractères, ou si le mot de passe de `DATABASE_URL` est l'un des mots de passe de développement de l'Infra (`config_service_dev`, `postgres`…) — voir `src/partage/secrets-production.ts`. Le message d'erreur liste tous les problèmes d'un coup ; en développement, les valeurs par défaut de l'Infra restent acceptées. Générer de vraies valeurs, par ex. `openssl rand -hex 32`.

## Exemple — récupérer sa configuration

```bash
curl http://localhost:3005/api/config-utilisateur \
  -H "x-internal-token: chatvardage_internal_dev" \
  -H "x-user-id: user-1"
```

Réponse (créée avec des valeurs par défaut au premier appel) :

```json
{
  "type": "configUtilisateur",
  "idUtilisateur": "user-1",
  "alias": null,
  "theme": "sombre",
  "langue": "fr",
  "statutPresence": "horsLigne",
  "vuLaDerniereFois": null,
  "modeNotification": "systeme"
}
```

## Exemple — modifier le thème et la langue

```bash
curl -X PATCH http://localhost:3005/api/config-utilisateur \
  -H "Content-Type: application/json" \
  -H "x-internal-token: chatvardage_internal_dev" \
  -H "x-user-id: user-1" \
  -d '{"theme":"clair","langue":"en"}'
```

## Exemple — mettre à jour la présence

```bash
curl -X PUT http://localhost:3005/api/config-utilisateur/presence \
  -H "Content-Type: application/json" \
  -H "x-internal-token: chatvardage_internal_dev" \
  -H "x-user-id: user-1" \
  -d '{"statut":"enLigne"}'
```

`vuLaDerniereFois` est mis à jour à **chaque** appel à cette route, y compris en passant `statut: "horsLigne"`. C'est volontaire : ce champ représente « vu(e) pour la dernière fois », qui doit correspondre à l'instant de la déconnexion (convention utilisée par WhatsApp/Messenger/Telegram), pas à la dernière connexion. Le frontend n'a pas besoin de lire ce champ quand `statutPresence` vaut `enLigne` (il affiche alors un indicateur « en ligne » plutôt qu'un horodatage).

## Base de données

Le service possède un seul modèle, une ligne par utilisateur :

```text
ConfigUtilisateur
├── idUtilisateur    (clé primaire, chaîne)
├── alias            (optionnel)
├── theme            (sombre | clair, défaut sombre)
├── langue           (fr | en, défaut fr)
├── statutPresence   (enLigne | horsLigne, défaut horsLigne)
├── vuLaDerniereFois (horodatage, optionnel)
├── modeNotification (systeme | discret | aucune, défaut systeme)
├── creeLe
└── misAJourLe
```

L'identifiant utilisateur est conservé sous forme de chaîne plutôt que comme clé étrangère vers `User`, car le modèle utilisateur appartient au service Authentification.

## Migration Prisma

Pour créer une nouvelle migration pendant le développement :

```bash
npx prisma migrate dev --name nom_de_la_migration
```

Dans Docker ou en déploiement :

```bash
npx prisma migrate deploy
```

Cette commande est lancée directement dans le `CMD` du conteneur (voir `Dockerfile`), avant de démarrer le serveur. C'est adapté à un déploiement **mono-replica**, comme la stack locale ; en multi-replica, plusieurs instances démarrant simultanément pourraient tenter d'appliquer les mêmes migrations en parallèle. Voir `AGENTS.md` (« Décisions de conception à préserver ») pour le détail de ce choix et les conditions dans lesquelles le revoir.

## Healthcheck

```bash
curl http://localhost:3005/api/health
```

Réponse attendue :

```json
{
  "status": "ok",
  "service": "user-config-service",
  "database": "ok",
  "timestamp": "..."
}
```

## Intégration avec Chatvardage

Ce service est la source de vérité des préférences du client Electron. Le process principal (`main.js`) en garde une copie, chargée à l'ouverture de session et diffusée aux pages (`preferences:change`) :

- le thème (`sombre` | `clair`) : modifiable uniquement depuis la page profil — les écrans de connexion/inscription n'ont plus de sélecteur de thème, ils réutilisent le dernier thème connu;
- la langue (`fr` | `en`) : si elle est explicitement changée sur l'écran de connexion ou d'inscription, elle est **enregistrée dans ce service** juste après l'ouverture de session (`PATCH /api/config-utilisateur`), au lieu d'être remplacée par celle déjà stockée. Sans choix explicite, la langue enregistrée ici s'applique, tout comme lors d'une reprise de session (jeton persisté);
- la présence (`PUT /api/config-utilisateur/presence`, renvoyé toutes les 20 s comme signe de vie);
- le mode de notification (`systeme` | `discret` | `aucune`).

## Place du service dans l'architecture

Le projet d'équipe est séparé en responsabilités :

```text
Frontend Electron
      |
      v
Serveur-API (Gateway)
      |
      +--> Authentification
      +--> Room-Service
      +--> Message-Service
      +--> User-Config-Service   <-- ce dépôt

Dashboard Admin --> Authentification / Room-Service / Message-Service

Infra --> Docker Compose + PostgreSQL + Redis + configuration globale
```

Le **User-Config-Service ne gère volontairement ni l'authentification, ni les salons, ni les messages, ni le temps réel**. Il reste un service de préférences interrogé en REST classique.

## Vérifications avant publication

À partir d'un clone propre du dépôt :

```bash
docker compose -f compose.local.yml up --build
curl http://localhost:3005/api/health
```

Puis, pour vérifier le code hors Docker :

```bash
npm ci
npx prisma generate
npm run build
npm test
npm run test:e2e
npm run test:cov
npm run lint
```

Le `docker-compose.yml` global du dépôt `Infra` demeure le point de démarrage de l'environnement complet de l'équipe pour la validation.
