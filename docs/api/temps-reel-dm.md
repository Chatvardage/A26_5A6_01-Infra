# Temps réel DM — Redis Pub/Sub + Socket.IO

Règle importante : **aucun événement Socket.IO n'est envoyé directement juste après l'appel de création du message.**

Le chemin obligatoire est :

`DB -> Redis PUBLISH -> Redis SUBSCRIBE -> Socket.IO`

Cela garantit que les messages envoyés par REST et ceux envoyés par WebSocket utilisent exactement le même mécanisme de diffusion temps réel.

## Création

`MessagesService.create()` :
- applique la limite d'envoi (10 messages / 10 s par utilisateur, salons compris), avant toute autre vérification : une tentative refusée compte aussi ;
- refuse un message à soi-même (400) et un destinataire inexistant (404, vérifié auprès d'Authentification par `GET /api/users/lookup` avec le jeton de l'expéditeur, mémorisé 10 min) ;
- écrit dans `PrivateMessage`;
- attend la réussite de Prisma;
- publie `private-message.created`.

`MessagesGateway.afterInit()` :
- subscribe aux événements Redis.

À la réception :
- parse le payload;
- récupère `senderId` et `recipientId`;
- émet vers `user:<senderId>`;
- émet vers `user:<recipientId>`.

## Modification / suppression

Même principe avec :
- `private-message.updated`
- `private-message.deleted`

Pour une suppression, l'événement contient encore `senderId` et `recipientId`, même si la ligne vient d'être supprimée, afin de savoir quels clients doivent recevoir l'événement.

La suppression d'un compte (`DELETE /api/internal/users/:userId`, appelée par Authentification) efface ses conversations **sans événement temps réel** (voir [temps réel salons](../api/temps-reel-salons.md), « Effacements en masse »).

## Authentification

Les connexions REST utilisent `Authorization: Bearer <JWT>` et Socket.IO utilise `auth.token`. Message-Service ne décode pas le jeton lui-même : il le fait valider par Authentification (`GET /api/auth/me`) et prend l'`id` de l'utilisateur renvoyé. Un identifiant fourni par le client (`x-user-id`, `handshake.auth.userId`) n'est jamais accepté.

## Authentification et origine WebSocket

La validation du JWT est déléguée à Auth-Service et utilise `AUTH_SERVICE_TIMEOUT_MS` (3000 ms par défaut) ; un jeton validé est mémorisé `AUTH_CACHE_TTL_MS` (10 s par défaut, voir le [guide Message-Service](../services/Message-Service.md#authentification)). Les origines présentes dans l’en-tête `Origin` doivent appartenir à `CORS_ORIGINS`. Une connexion sans en-tête `Origin` est acceptée volontairement pour permettre les clients non-navigateurs, notamment Electron/Socket.IO.
