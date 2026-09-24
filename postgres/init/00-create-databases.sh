#!/bin/sh
set -eu

create_role_and_db() {
  db="$1"
  user="$2"
  pass="$3"

  if [ -z "$db" ]; then
    echo "Nom de base vide" >&2
    exit 1
  fi

  if [ -z "$user" ]; then
    echo "Nom de rôle vide" >&2
    exit 1
  fi

  # Les identifiants SQL ne peuvent contenir que lettres, chiffres et underscore.
  case "$db" in
    *[!A-Za-z0-9_]*)
      echo "Nom de base invalide: $db" >&2
      exit 1
      ;;
  esac

  case "$user" in
    *[!A-Za-z0-9_]*)
      echo "Nom de rôle invalide: $user" >&2
      exit 1
      ;;
  esac

  if [ -z "$pass" ]; then
    echo "Mot de passe vide pour le rôle: $user" >&2
    exit 1
  fi

  # Refuser les retours à la ligne et retours chariot dans le mot de passe
  # (presque toujours une erreur de copie dans .env).
  # (Un littéral est requis pour \n : $(printf '\n') serait vidé par la substitution.)
  nl='
'
  cr=$(printf '\r')
  case "$pass" in
    *"$nl"*|*"$cr"*)
      echo "Mot de passe invalide pour le rôle $user : caractères de contrôle interdits" >&2
      exit 1
      ;;
  esac

  # Les valeurs sont passées en variables psql (-v) et le heredoc est quoté :
  # le shell n'interpole rien dans le SQL, et psql échappe lui-même les valeurs
  # (:'var' pour un littéral, :"var" pour un identifiant). Pas de bloc DO : psql
  # n'interpole pas ses variables à l'intérieur d'une chaîne $$...$$.
  # Si le rôle existe déjà (script rejoué à la main), son mot de passe est
  # réaligné sur .env au lieu d'être ignoré silencieusement.
  psql -v ON_ERROR_STOP=1 -v db="$db" -v user="$user" -v pass="$pass" \
    --username "$POSTGRES_USER" --dbname postgres <<'SQL'
SELECT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = :'user') AS role_exists \gset
\if :role_exists
ALTER ROLE :"user" WITH LOGIN PASSWORD :'pass';
\else
CREATE ROLE :"user" LOGIN PASSWORD :'pass';
\endif
SELECT format('CREATE DATABASE %I OWNER %I', :'db', :'user')
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = :'db') \gexec
-- Par défaut, PUBLIC peut se connecter à toute base : le compte d'un service
-- ouvrait donc aussi celles des autres. Seul le propriétaire (et le
-- superutilisateur) garde la connexion.
SELECT format('REVOKE CONNECT, TEMPORARY ON DATABASE %I FROM PUBLIC', :'db') \gexec
SQL
}

create_role_and_db "$AUTH_DB" "$AUTH_DB_USER" "$AUTH_DB_PASSWORD"
create_role_and_db "$ROOMS_DB" "$ROOMS_DB_USER" "$ROOMS_DB_PASSWORD"
create_role_and_db "$MESSAGES_DB" "$MESSAGES_DB_USER" "$MESSAGES_DB_PASSWORD"
create_role_and_db "$CONFIG_DB" "$CONFIG_DB_USER" "$CONFIG_DB_PASSWORD"
