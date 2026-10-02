#!/bin/sh
set -eu

# Usage : ./scripts/verifier-fichiers-partages.sh
# Vérifie que les fichiers partagés (src/partage/) sont identiques dans tous
# les dépôts qui les copient. Les dépôts doivent être clonés côte à côte,
# comme pour docker-compose.yml (../A26_5A6_01-*).

cd "$(dirname "$0")/../.."

echec=0

# $1 : fichier (relatif à src/partage/) ; ensuite : les dépôts qui le copient.
verifier() {
  fichier=$1
  shift
  reference=""
  for depot in "$@"; do
    chemin="$depot/src/partage/$fichier"
    if [ ! -f "$chemin" ]; then
      echo "ABSENT    $chemin" >&2
      echec=1
      continue
    fi
    if [ -z "$reference" ]; then
      reference=$chemin
    elif ! cmp -s "$reference" "$chemin"; then
      echo "DIFFÉRENT $chemin (comparé à $reference)" >&2
      echec=1
      continue
    fi
    echo "ok        $chemin"
  done
}

AUTH_CLIENTS="A26_5A6_01-Room-Service A26_5A6_01-Message-Service"
SECRETS="A26_5A6_01-Room-Service A26_5A6_01-Message-Service A26_5A6_01-User-Config-Service"

# shellcheck disable=SC2086 # listes de dépôts séparées par des espaces
verifier client-auth.ts $AUTH_CLIENTS
# shellcheck disable=SC2086
verifier client-auth.spec.ts $AUTH_CLIENTS
# shellcheck disable=SC2086
verifier secrets-production.ts $SECRETS
# shellcheck disable=SC2086
verifier secrets-production.spec.ts $SECRETS

if [ "$echec" -ne 0 ]; then
  echo "Des fichiers partagés ont divergé : reporter la même modification dans chaque dépôt." >&2
  exit 1
fi
echo "Fichiers partagés identiques."
