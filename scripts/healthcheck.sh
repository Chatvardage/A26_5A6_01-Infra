#!/bin/sh
set -eu

echo "== PostgreSQL =="
docker compose exec -T postgres pg_isready -U postgres -d postgres

echo "== Databases =="
docker compose exec -T postgres psql -U postgres -d postgres -Atc "SELECT datname FROM pg_database WHERE datname LIKE 'chatvardage_%' ORDER BY datname;"

echo "== Redis =="
docker compose exec -T -e REDISCLI_AUTH="${REDIS_PASSWORD:-chatvardage_redis_dev}" redis redis-cli ping

echo "Infrastructure OK"