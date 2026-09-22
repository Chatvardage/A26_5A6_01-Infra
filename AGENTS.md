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
Vérifier que PostgreSQL et Redis sont `healthy`.

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
