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

Ces décisions ne remplacent pas les validations obligatoires avant PR indiquées plus haut.

### Validation effectuée le 1er octobre 2026

- Configuration Compose valide avec `DASHBOARD_SESSION_SECRET` renseigné; refus attendu avec une valeur vide.
- Stack construite et démarrée avec `docker compose up -d --build --wait --wait-timeout 180` après `docker compose down -v`, dans le projet isolé `chatvardage-validation-6622a39`. La configuration de validation dérive de `docker compose --env-file .env.example config --format json`; seuls le nom du projet, les noms explicites des conteneurs/réseaux/volumes et les ports publiés ont été adaptés pour isoler la stack. Aucun port hôte n’est publié pendant cette validation; les accès depuis l’hôte ne sont donc pas couverts. Les volumes locaux habituels sont préservés.
- `docker compose ps` : PostgreSQL, Redis, Auth, Room, Message, User-Config, Serveur-API et Dashboard sont `healthy`; Adminer est démarré.
- `./scripts/healthcheck.sh` : quatre bases présentes, Redis répond `PONG`, cinq services sains et `/api/health/upstreams` renvoie `ok` pour tous les services.
- Logs PostgreSQL/Redis examinés : initialisation terminée et services prêts. Les trois migrations Prisma Room-Service ont été réellement appliquées sur la base neuve; une nouvelle exécution de `npx prisma migrate deploy` confirme qu’aucune migration ne reste à appliquer.
- Room-Service validé dans une image Docker Node 22 construite avec la cible `build` de son Dockerfile (`npm ci` dans la cible de dépendances) : `npx prisma generate`, `npm run lint`, `npm test -- --runInBand` (196 tests), `npm run test:e2e -- --runInBand` (14 tests), `npm run build` et `npm run test:cov -- --runInBand` passent. Couverture : 100 % Statements, Branches, Functions et Lines.
- Syntaxe des quatre scripts shell vérifiée avec `sh -n`; `./scripts/verifier-fichiers-partages.sh` confirme que les fichiers partagés sont identiques. Les scripts locaux ont été remis en LF et rendus exécutables conformément à Git et `.gitattributes`; cela ne change pas leur contenu versionné.
- La construction du Dashboard réussit, mais affiche des avertissements `EBADENGINE` : son image Node 20 est plus ancienne que la version demandée par certaines dépendances. Ce point appartient au dépôt Dashboard et reste à traiter séparément.
- La stack de validation et ses volumes temporaires sont supprimés après les contrôles.

### Correction du CI après validation locale

Le run GitHub Actions `36891758599` sur `3c301c2` a échoué à l’étape `docker compose --env-file .env.example config -q` : le modèle contient volontairement un `DASHBOARD_SESSION_SECRET` vide. La validation de la stack avec un secret fourni ne couvrait pas cette invocation du workflow.

Le job `compose-et-scripts` génère maintenant un secret temporaire avec `openssl rand -hex 32`, limité à la commande de validation Compose. Aucun secret réel ni valeur fixe ne doit être ajouté à `.env.example` pour faire passer le CI. L’invocation corrigée de Compose et ShellCheck sur les quatre scripts passent localement. Le prochain run GitHub Actions reste à confirmer après publication du commit.

### Suite de la revue : fins de ligne et secret de cookie

- `.gitattributes` impose désormais LF aux fichiers texte (`* text=auto eol=lf`), avec une règle explicite pour les scripts shell. Les fichiers texte suivis ont été normalisés une seule fois; les modifications de fins de ligne ne changent pas leur logique.
- La suppression du repli `DASHBOARD_COOKIE_SECRET` n’est pas retenue dans cette correction. La valeur `dashboard_cookie_secret_for_local_development` sert de marqueur de développement : `resoudreSecrets()` la remplace par un secret aléatoire en développement/test et la rejette explicitement hors de ces modes, indépendamment de sa longueur. Elle n’est donc pas acceptée en production parce qu’elle dépasse 32 caractères. La consigne précédente sur le secret de session sans valeur publique concerne `DASHBOARD_SESSION_SECRET`; elle ne signifie pas que ce marqueur de cookie est utilisé comme clé cryptographique.
- La génération manuelle de `DASHBOARD_SESSION_SECRET` reste un choix explicite du démarrage Infra. Le README la place avant `docker compose up` et `.env.example` décrit l’obligation. Aucun message externe à l’équipe n’est envoyé automatiquement.
- Les décisions et résultats restent dans `AGENTS.md`, conformément à la demande de cette revue. Le déplacement vers un journal séparé pourra être envisagé si les entrées s’accumulent; il n’est pas nécessaire pour cette correction.
