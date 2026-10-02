# Chatvardage — Infrastructure et documentation

Point de départ du projet complet : client Electron, API Gateway, quatre services métier, Dashboard d’administration, PostgreSQL et Redis. Ce dépôt orchestre les conteneurs et rassemble la documentation. Chaque service conserve son code, ses tests et ses migrations.

## Prérequis

- Git et accès aux huit dépôts privés de l’organisation **Chatvardage**.
- Docker Engine 25+ / Docker Desktop avec Compose v2; Docker démarré.
- Bash sous Linux/macOS ou WSL sous Windows pour les scripts. Les commandes ci-dessous sont en Bash/WSL.
- Pour le client desktop depuis les sources : Node.js 22, npm et un bureau graphique. Le backend n’exige ni Rust, ni Node, ni PostgreSQL installés sur l’hôte.
- Ports locaux libres : 3000 à 3005, 5432, 6379 et 8081. Ne pas lancer les Compose individuels en même temps que la stack globale.

## Installation complète

Cloner les huit dépôts ci-dessous côte à côte.

```bash
mkdir Chatvardage
cd Chatvardage
for repo in Infra Frontend Serveur-API Authentification Room-Service Message-Service User-Config-Service Dashboard; do
  git clone --branch develop "https://github.com/Chatvardage/A26_5A6_01-$repo.git"
done
cd A26_5A6_01-Infra
cp .env.example .env
openssl rand -hex 32
```

Copier la valeur générée dans `DASHBOARD_SESSION_SECRET` de `.env`, puis enregistrer. Aucun secret réel ne doit être commité. Ces valeurs sont pour un poste local de développement; ce Compose n’est pas un déploiement de production.

Pour reproduire une version, utiliser les tags ou commits validés indiqués dans le [guide des versions](docs/versions.md).

```text
Chatvardage/
├── A26_5A6_01-Infra/                 # lancer Compose ici
├── A26_5A6_01-Frontend/
├── A26_5A6_01-Serveur-API/
├── A26_5A6_01-Authentification/
├── A26_5A6_01-Room-Service/
├── A26_5A6_01-Message-Service/
├── A26_5A6_01-User-Config-Service/
└── A26_5A6_01-Dashboard/
```

## Démarrer et tout vérifier

```bash
docker compose up --build -d --wait --wait-timeout 240
docker compose ps
./scripts/healthcheck.sh
```

`docker compose up --build` fonctionne aussi au premier plan. Au premier démarrage, PostgreSQL crée quatre bases et leurs propriétaires; les services appliquent automatiquement leurs migrations avant de devenir sains.

Le healthcheck vérifie réellement : PostgreSQL, connexion aux **quatre bases configurées**, Redis (`PONG`), les états `healthy` d’Auth, Room, Message, User-Config, Gateway **et Dashboard**, puis `GET /api/health/upstreams`. Il termine avec un code non nul en cas d’échec. Adminer est un outil de développement facultatif pour la validation, pas un service métier. La santé ne prouve pas à elle seule les fonctionnalités : suivre ensuite le [scénario de validation](docs/validation.md).

```bash./scripts/healthcheck.sh --infra       # PostgreSQL, quatre bases et Redis seulement
./scripts/verifier-fichiers-partages.sh
```

Le script s’appuie sur l’environnement des conteneurs, n’exécute pas `.env` comme du code et ne nécessite pas `curl` sur l’hôte.

| Point d’accès local | Usage |
|---|---|
| http://localhost:3000 | Gateway pour Electron, HTTP et Socket.IO |
| http://localhost:3000/api/health/upstreams | Diagnostic des quatre services métier |
| http://localhost:3002/administration | Dashboard AdminJS |
| http://localhost:3001/health | Authentification |
| http://localhost:3003/docs | Swagger Room-Service |
| http://localhost:3004/docs | Swagger Message-Service |
| http://localhost:3005/docs | Swagger User-Config-Service |
| http://localhost:8081 | Adminer, inspection PostgreSQL en développement |

Tous les ports publiés sont liés à `127.0.0.1`. Deux clients sur **le même poste**, avec deux profils Electron, conviennent à la démonstration. Les autres postes du réseau ne peuvent pas joindre cette configuration telle quelle.

## Ouvrir le client

```bash
cd ../A26_5A6_01-Frontend
npm ci
npm start
# Dans un deuxième terminal, après le premier build :
CHATVARDAGE_PROFIL=2 node scripts/start.js
```

Créer deux comptes distincts dans l’application. Le backend ciblé est `http://localhost:3000`. Sur une installation propre, la connexion est nécessaire; une session valide persistée ouvre ensuite le clavardage sans passage par le panneau de configuration.

## Créer le premier administrateur

Créer d’abord un compte standard dans Electron, puis depuis Infra promouvoir **ce compte uniquement**. Remplacer le pseudo ci-dessous par celui choisi :

```bash
docker compose exec postgres psql -U postgres -d chatvardage_auth
```

Dans `psql` :

```sql
UPDATE utilisateurs SET role = 'admin', version_auth = version_auth + 1
WHERE pseudo = 'pseudo_du_compte';
\q
```

Vérifier que `UPDATE 1` est affiché. Reconnecter ce compte puis ouvrir le Dashboard. Si les noms PostgreSQL ont été personnalisés dans `.env`, adapter `-U` et `-d`. Cette opération de démarrage est locale et ne crée aucune route publique de promotion. Les promotions suivantes passent par un admin existant.

## Arrêter, diagnostiquer et préserver les données

```bash
docker compose stop                  # arrêt sans suppression
docker compose up -d --wait          # reprise avec les données
docker compose logs --tail=100 auth-service room-service message-service user-config-service serveur-api dashboard
```

- Secret absent : renseigner `DASHBOARD_SESSION_SECRET` avant toute commande Compose.
- Chemin de build absent : vérifier les huit dossiers voisins, particulièrement Dashboard.
- Port occupé : arrêter l’autre environnement ou choisir des ports distincts dans une configuration de test.
- API saine mais connexion impossible : examiner Auth et les migrations; un healthcheck ne crée pas de compte.
- JWT expiré/révoqué : se reconnecter; les droits des services peuvent être mémorisés 10 s.
- Redis indisponible : un message peut déjà être écrit en base avant l’échec de publication. Relire l’historique avant de réessayer pour éviter un doublon; il n’y a pas de transaction distribuée ni de file de reprise durable.
- Notifications sous WSL : l’affichage natif dépend de D-Bus/du bureau. L’application possède un repli visuel; vérifier les notifications sur l’OS cible.

`docker compose down` conserve les volumes. **`./scripts/reset.sh` et `docker compose down -v` effacent les données** : réserver ces commandes à un environnement jetable. Pour une validation propre, utiliser le protocole isolé de `docs/validation.md`.

## Documentation centrale

- [Architecture applications et conteneurs](docs/architecture.md), [image PNG](docs/architecture.png) et [source SVG](docs/architecture.svg)
- [Architecture interne du frontend](docs/architecture-frontend.md)
- [Bases, propriétaires et migrations](docs/database.md)
- [Contrats HTTP, rôles et événements](docs/api/README.md)
- [Guides détaillés par dépôt](docs/services/README.md)
- [Validation, démonstration et résultats](docs/validation.md)
- [Versions et publication](docs/versions.md)
- [Synchronisation facultative des clones](scripts/info-upll-clone.md)

## CI Infra

Le CI valide Compose avec un secret de session temporaire, vérifie les scripts avec ShellCheck et compare les fichiers partagés entre services. Pour les dépôts privés, la comparaison requiert `CHATVARDAGE_REPOS_TOKEN` (lecture des contenus uniquement); sans ce secret, elle est signalée comme sautée. Les contrôles de chaque service restent dans leurs dépôts.
