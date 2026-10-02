#!/usr/bin/env sh
set -eu

# Génère A26_5A6_01-Infra/.env à partir de .env.example en remplaçant
# toutes les valeurs sensibles par des secrets hexadécimaux aléatoires.
# Usage : ./scripts/generer-env.sh [--force]

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
INFRA_DIR=$(dirname "$SCRIPT_DIR")
TEMPLATE="$INFRA_DIR/.env.example"
TARGET="$INFRA_DIR/.env"
FORCE=0

if [ "${1:-}" = "--force" ]; then
  FORCE=1
elif [ "$#" -gt 0 ]; then
  echo "Usage: $0 [--force]" >&2
  exit 2
fi

if ! command -v openssl >/dev/null 2>&1; then
  echo "Erreur: openssl est requis pour générer des secrets cryptographiquement sûrs." >&2
  exit 1
fi

if [ ! -f "$TEMPLATE" ]; then
  echo "Erreur: modèle introuvable: $TEMPLATE" >&2
  exit 1
fi

if [ -e "$TARGET" ] && [ "$FORCE" -ne 1 ]; then
  echo "Erreur: $TARGET existe déjà. Utilisez --force pour le remplacer." >&2
  exit 1
fi

secret() {
  openssl rand -hex 32
}

# Tous ces secrets sont distincts. Les mots de passe sont hexadécimaux afin
# d'être sûrs dans les URL PostgreSQL/Redis sans encodage supplémentaire.
POSTGRES_SUPERPASS_VALUE=$(secret)
AUTH_DB_PASSWORD_VALUE=$(secret)
ROOMS_DB_PASSWORD_VALUE=$(secret)
MESSAGES_DB_PASSWORD_VALUE=$(secret)
CONFIG_DB_PASSWORD_VALUE=$(secret)
REDIS_PASSWORD_VALUE=$(secret)
JWT_SECRET_VALUE=$(secret)
INTERNAL_SERVICE_TOKEN_VALUE=$(secret)
DASHBOARD_COOKIE_SECRET_VALUE=$(secret)
DASHBOARD_SESSION_SECRET_VALUE=$(secret)

umask 077
TMP="$TARGET.tmp.$$"
trap 'rm -f "$TMP"' EXIT HUP INT TERM

while IFS= read -r line || [ -n "$line" ]; do
  case "$line" in
    POSTGRES_SUPERPASS=*) echo "POSTGRES_SUPERPASS=$POSTGRES_SUPERPASS_VALUE" ;;
    AUTH_DB_PASSWORD=*) echo "AUTH_DB_PASSWORD=$AUTH_DB_PASSWORD_VALUE" ;;
    ROOMS_DB_PASSWORD=*) echo "ROOMS_DB_PASSWORD=$ROOMS_DB_PASSWORD_VALUE" ;;
    MESSAGES_DB_PASSWORD=*) echo "MESSAGES_DB_PASSWORD=$MESSAGES_DB_PASSWORD_VALUE" ;;
    CONFIG_DB_PASSWORD=*) echo "CONFIG_DB_PASSWORD=$CONFIG_DB_PASSWORD_VALUE" ;;
    REDIS_PASSWORD=*) echo "REDIS_PASSWORD=$REDIS_PASSWORD_VALUE" ;;
    JWT_SECRET=*) echo "JWT_SECRET=$JWT_SECRET_VALUE" ;;
    INTERNAL_SERVICE_TOKEN=*) echo "INTERNAL_SERVICE_TOKEN=$INTERNAL_SERVICE_TOKEN_VALUE" ;;
    DASHBOARD_COOKIE_SECRET=*) echo "DASHBOARD_COOKIE_SECRET=$DASHBOARD_COOKIE_SECRET_VALUE" ;;
    DASHBOARD_SESSION_SECRET=*) echo "DASHBOARD_SESSION_SECRET=$DASHBOARD_SESSION_SECRET_VALUE" ;;
    *) printf '%s\n' "$line" ;;
  esac
done < "$TEMPLATE" > "$TMP"

mv "$TMP" "$TARGET"
trap - EXIT HUP INT TERM

echo "OK: .env créé avec des secrets aléatoires distincts."
echo "Fichier: $TARGET"
echo "Ne jamais committer ni partager ce fichier."
