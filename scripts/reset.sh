#!/bin/sh
set -eu

printf "Cela va supprimer tous les volumes (donnees perdues). Continuer ? [y/N] "
read -r ans
case "$ans" in
  [yY]) ;;
  *) echo "Annule."; exit 0 ;;
esac

docker compose down -v --remove-orphans
docker compose up -d --build
