#!/bin/sh
set -eu

# Exécuter depuis la racine du dépôt, où se trouvent docker-compose.yml et .env.
cd "$(dirname "$0")/.."

# Les identifiants sont lus dans l'environnement des conteneurs (fourni par
# docker compose à partir de .env) : ce script ne lit ni n'exécute .env lui-même.

echo "== PostgreSQL =="
docker compose exec -T postgres sh -c 'pg_isready -U "$POSTGRES_USER" -d postgres'

echo "== Databases =="
docker compose exec -T postgres sh -c 'psql -U "$POSTGRES_USER" -d postgres -Atc "$1"' _ \
  "SELECT datname FROM pg_database WHERE datname LIKE 'chatvardage_%' ORDER BY datname;"

echo "== Redis =="
# REDISCLI_AUTH est défini dans le service redis de docker-compose.yml.
redis_reply=$(docker compose exec -T redis redis-cli ping)
echo "$redis_reply"
if [ "$redis_reply" != "PONG" ]; then
  echo "Redis ne répond pas PONG" >&2
  exit 1
fi

echo "Infrastructure OK"
