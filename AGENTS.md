# AGENTS.md — A26_5A6_01-Infra

## Mission
Orchestrer l'environnement du Contrôle 2 Chatvardage. Ce dépôt ne contient aucune logique métier et **ne possède aucun schéma métier**.

## Responsabilités d'Infra
- lancer PostgreSQL et Redis;
- créer les quatre bases logiques et leurs utilisateurs/propriétaires SQL;
- gérer réseaux, volumes, variables d'environnement et healthchecks;
- fournir le Docker Compose racine et les scripts de santé/reset;
- documenter l'orchestration de la stack.

## Règle impérative : propriété des schémas
Ne jamais créer dans `postgres/init` les tables métier, index métier ou données métier des services.
- Authentification possède ses tables/migrations.
- Room-Service possède salons/membres/invitations et ses migrations Prisma.
- Message-Service possède conversations/messages privés et ses migrations.
- User-Config-Service possède configurations et ses migrations.

`postgres/init/00-create-databases.sh` peut créer les **bases, rôles et propriétaires**, rien de plus.

## Redis
Redis sert au transport/temps réel et ne remplace jamais PostgreSQL. Pour le C2, le temps réel obligatoire concerne les messages privés. Ne pas ajouter la persistance des messages de salons dans Infra.

## Validation obligatoire avant PR
Exécuter :
```bash
docker compose config
docker compose down -v
docker compose up -d --build
docker compose ps
./scripts/healthcheck.sh
docker compose logs --no-color --tail=100 postgres redis
```
Vérifier que PostgreSQL et Redis sont `healthy`. `./scripts/healthcheck.sh` vérifie aussi les cinq microservices et `/api/health/upstreams` du Gateway ; `./scripts/healthcheck.sh --infra` se limite à PostgreSQL et Redis.

Puis valider au moins une migration réelle d'un microservice contre une base neuve. Pour Room-Service :
```bash
npx prisma generate
npx prisma migrate deploy
npm run lint
npm test
npm run test:e2e
npm run build
```
Ne jamais déclarer la PR prête si une commande requise échoue.

## Après modification de l'initialisation PostgreSQL
Les scripts `/docker-entrypoint-initdb.d` ne s'exécutent que sur un volume neuf :
```bash
docker compose down -v
docker compose up -d
```
Attention : cela efface les données locales.

## Variables et sécurité
`.env` ne doit jamais être commité. `.env.example` contient seulement des identifiants de développement. Un service doit utiliser uniquement le compte SQL de sa propre base.

Tout port publié dans `docker-compose.yml` doit être lié à `127.0.0.1` (`"127.0.0.1:PORT:PORT"`), jamais à toutes les interfaces.

Les origines CORS viennent d'une seule variable de `.env`, `CORS_ORIGINS`. Tous les services, Auth-Service compris, la lisent sous ce même nom. Ne pas réintroduire une seconde variable CORS dans `.env.example`.

## Revue Infra — adaptation du Dashboard : recommandations non retenues

Les décisions suivantes reposent sur le code des services au moment de cette revue :

- **Ne pas ajouter de secret de session connu par défaut**, ni dans Compose ni comme valeur de développement dans `.env.example`. `DASHBOARD_SESSION_SECRET` reste vide dans le modèle, avec une instruction de génération (`openssl rand -hex 32`). Compose exige une valeur non vide avec `${DASHBOARD_SESSION_SECRET:?…}`. Cela rend la configuration explicite et évite de fournir un secret public réutilisable.
- **Ne pas créer `USER_CONFIG_SESSION_SECRET` et ne pas renommer le secret du Dashboard en secret partagé.** User-Config-Service ne consomme pas `SESSION_SECRET`; son identité HTTP provient de `x-user-id`, protégé par `INTERNAL_SERVICE_TOKEN`. L’injection inutile a été supprimée. `DASHBOARD_SESSION_SECRET` ne concerne donc que le Dashboard et son nom reste approprié.
- **Ne pas documenter de nouvelles sessions HTTP pour User-Config-Service** dans le README ou dans la documentation d’architecture : aucun mécanisme de ce type ne figure dans son code. La suppression de la variable conserve le mécanisme existant.
- **Ne pas retenir la qualification de faille critique pour la valeur vide à elle seule.** Dans `dashboard-chatvardage/src/main.ts`, `resoudreSecrets()` génère des secrets aléatoires en développement/test lorsque la valeur est absente et refuse une valeur absente ou trop courte en production. Le Dashboard ne signe donc pas ses sessions avec une chaîne vide dans ces cas. L’exigence ajoutée dans Compose clarifie la configuration en amont.

Ces décisions ne remplacent pas les validations obligatoires avant PR indiquées plus haut. La configuration Compose a été vérifiée avec une valeur présente et avec une valeur vide (refus attendu); la validation complète de la stack reste à effectuer avant de déclarer une PR prête.
