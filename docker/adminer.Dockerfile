# Appliquer les correctifs système disponibles à chaque rebuild --pull.
FROM adminer:6.1.1-standalone
USER root
RUN apk upgrade --no-cache
