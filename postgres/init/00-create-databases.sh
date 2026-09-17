#!/bin/sh
set -eu

create_role_and_db() {
  db="$1"
  user="$2"
  pass="$3"

  # Les identifiants SQL ne peuvent contenir que lettres, chiffres et underscore.
  case "$db" in *[!A-Za-z0-9_]*) echo "Nom de base invalide: $db" >&2; exit 1 ;; esac
  case "$user" in *[!A-Za-z0-9_]*) echo "Nom de rôle invalide: $user" >&2; exit 1 ;; esac

  # Échapper les apostrophes du mot de passe avant de l'insérer comme littéral SQL.
  escaped_pass=$(printf "%s" "$pass" | sed "s/'/''/g")

  psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname postgres <<SQL
DO \$\$ BEGIN
  IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = '$user') THEN
    CREATE ROLE $user LOGIN PASSWORD '$escaped_pass';
  END IF;
END \$\$;
SELECT 'CREATE DATABASE $db OWNER $user' WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = '$db')\gexec
SQL
}

create_role_and_db "$AUTH_DB" "$AUTH_DB_USER" "$AUTH_DB_PASSWORD"
create_role_and_db "$ROOMS_DB" "$ROOMS_DB_USER" "$ROOMS_DB_PASSWORD"
create_role_and_db "$MESSAGES_DB" "$MESSAGES_DB_USER" "$MESSAGES_DB_PASSWORD"
create_role_and_db "$CONFIG_DB" "$CONFIG_DB_USER" "$CONFIG_DB_PASSWORD"
