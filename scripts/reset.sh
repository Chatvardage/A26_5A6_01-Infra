#!/bin/sh

set -eu

printf 'ATTENTION : cette commande va supprimer tous les volumes Docker et donc les données locales.\n'
printf 'Continuer ? [y/N] '

read -r ans

case "$ans" in
  [yY])
    ;;
  *)
    echo "Annulé."
    exit 0
    ;;
esac

docker compose down -v --remove-orphans
docker compose up -d --build