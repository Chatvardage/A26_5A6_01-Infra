#!/bin/sh
set -eu

# Exécuter depuis la racine du dépôt, où se trouvent docker-compose.yml et .env.
cd "$(dirname "$0")/.."

# Charger .env (s'il existe) pour utiliser les mêmes identifiants que docker compose.
if [ -f .env ]; then
  set -a
  . ./.env
  set +a
fi

echo "== PostgreSQL =="
docker compose exec -T postgres pg_isready -U "${POSTGRES_SUPERUSER:-postgres}" -d postgres

echo "== Databases =="
docker compose exec -T postgres psql -U "${POSTGRES_SUPERUSER:-postgres}" -d postgres -Atc "SELECT datname FROM pg_database WHERE datname LIKE 'chatvardage_%' ORDER BY datname;"

echo "== Redis =="
docker compose exec -T -e REDISCLI_AUTH="${REDIS_PASSWORD:-chatvardage_redis_dev}" redis redis-cli ping

echo "Infrastructure OK"
