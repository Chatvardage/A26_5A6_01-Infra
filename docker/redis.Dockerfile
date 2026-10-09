# Appliquer les correctifs système disponibles à chaque rebuild --pull.
FROM redis:7.4-alpine
USER root
RUN apk upgrade --no-cache
