#!/bin/sh
set -eu

# Usage : ./scripts/healthcheck.sh [--infra]
# Sans option : vérifie PostgreSQL, Redis, les microservices et le Gateway.
# --infra : vérifie uniquement PostgreSQL et Redis (microservice lancé sur l'hôte).

infra_only=0

for arg in "$@"; do
  case "$arg" in
    --infra)
      infra_only=1
      ;;
    -h|--help)
      echo "Usage : $0 [--infra]"
      exit 0
      ;;
    *)
      echo "Option inconnue : $arg" >&2
      echo "Usage : $0 [--infra]" >&2
      exit 2
      ;;
  esac
done

# Exécuter depuis la racine du dépôt, où se trouvent docker-compose.yml et .env.
cd "$(dirname "$0")/.."

# Les identifiants sont lus dans l'environnement des conteneurs (fourni par
# docker compose à partir de .env) : ce script ne lit ni n'exécute .env lui-même.

echo "== PostgreSQL =="
docker compose exec -T postgres sh -c 'pg_isready -U "$POSTGRES_USER" -d postgres'

echo "== Databases =="
docker compose exec -T postgres sh -eu -c '
  for db in "$AUTH_DB" "$ROOMS_DB" "$MESSAGES_DB" "$CONFIG_DB"; do
    psql -U "$POSTGRES_USER" -d "$db" -v ON_ERROR_STOP=1 -Atc "SELECT 1" >/dev/null
    echo "$db : accessible"
  done
'

echo "== Redis =="
# REDISCLI_AUTH est défini dans le service redis de docker-compose.yml.
redis_reply=$(docker compose exec -T redis redis-cli ping)
echo "$redis_reply"
if [ "$redis_reply" != "PONG" ]; then
  echo "Redis ne répond pas PONG" >&2
  exit 1
fi

if [ "$infra_only" -eq 1 ]; then
  echo "Infrastructure OK"
  exit 0
fi

echo "== Microservices =="
# État rapporté par les healthchecks de docker-compose.yml. On vérifie tous les
# services avant d'échouer, pour afficher un diagnostic complet.
failed=0
for service in auth-service room-service message-service user-config-service serveur-api dashboard; do
  container_id=$(docker compose ps -q "$service")
  if [ -z "$container_id" ]; then
    status="non démarré"
  else
    status=$(docker inspect -f '{{if .State.Health}}{{.State.Health.Status}}{{else}}{{.State.Status}}{{end}}' "$container_id")
  fi
  echo "$service : $status"
  if [ "$status" != "healthy" ]; then
    failed=1
  fi
done

if [ "$failed" -ne 0 ]; then
  echo "Au moins un microservice n'est pas healthy : voir 'docker compose logs <service>'." >&2
  exit 1
fi

echo "== Gateway (upstreams) =="
# Appel depuis le conteneur du Gateway : ne dépend pas de curl sur l'hôte.
# /api/health/upstreams répond 200 si auth, room, message et userConfig sont ok, 503 sinon.
if ! docker compose exec -T serveur-api node -e "
fetch('http://localhost:3000/api/health/upstreams')
  .then(async (r) => { console.log(await r.text()); process.exit(r.ok ? 0 : 1); })
  .catch((e) => { console.error(e.message); process.exit(1); });
"; then
  echo "Le Gateway signale au moins un service indisponible." >&2
  exit 1
fi

echo "Stack OK"
