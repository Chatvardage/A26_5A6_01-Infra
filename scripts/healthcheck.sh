#!/bin/sh
set -eu
. ./.env 2>/dev/null || true
echo "== PostgreSQL =="
docker compose exec -T postgres pg_isready -U "${POSTGRES_SUPERUSER:-postgres}" -d postgres
echo "== Databases =="
docker compose exec -T postgres psql -U "${POSTGRES_SUPERUSER:-postgres}" -d postgres -Atc "SELECT datname FROM pg_database WHERE datname LIKE 'chatvardage_%' ORDER BY datname;"
echo "== Redis =="
docker compose exec -T redis redis-cli -a "${REDIS_PASSWORD:-chatvardage_redis_dev}" ping
echo "Infrastructure OK"
