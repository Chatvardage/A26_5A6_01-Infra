# Appliquer les correctifs système disponibles à chaque rebuild --pull.
FROM postgres:17-alpine
USER root
RUN apk upgrade --no-cache
