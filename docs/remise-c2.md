# Manifeste de remise C2

## Dépôts et versions

| Dépôt | Version déclarée | Tag C2 |
|---|---|---|
| [Frontend](https://github.com/Chatvardage/A26_5A6_01-Frontend) | 2.0.0 | À publier après validation |
| [Serveur-API](https://github.com/Chatvardage/A26_5A6_01-Serveur-API) | 1.0.0 | À publier après validation |
| [Authentification](https://github.com/Chatvardage/A26_5A6_01-Authentification) | 1.0.0 | À publier après validation |
| [Room-Service](https://github.com/Chatvardage/A26_5A6_01-Room-Service) | 1.0.0 | À publier après validation |
| [Message-Service](https://github.com/Chatvardage/A26_5A6_01-Message-Service) | 1.0.0 | À publier après validation |
| [User-Config-Service](https://github.com/Chatvardage/A26_5A6_01-User-Config-Service) | 1.0.0 | À publier après validation |
| [Dashboard](https://github.com/Chatvardage/A26_5A6_01-Dashboard) | 1.0.0 | À publier après validation |
| [Infra](https://github.com/Chatvardage/A26_5A6_01-Infra) | sans package.json | À publier après validation |

La convention de remise est `1.0.0` pour les services et le Dashboard, et `2.0.0` pour Frontend. Infra utilise également `v1.0.0` comme tag de remise, sans ajouter un package.json à ce dépôt d’orchestration.

Les tags C2 ne sont pas encore publiés. Cette table ne prétend pas qu’une branche de travail est une remise définitive. Après revue/fusion, créer les tags sur les commits validés et remplacer la dernière colonne par leurs liens. Infra peut avoir son propre tag de remise; Mobile est hors périmètre C2.

Le desktop conserve les tags historiques C1 `v1.0.0` et `v1.0.1`. Le second déclare `1.0.0` dans package.json : on ne réécrit pas un tag déjà remis. La version C2 du desktop devient 2.0.0. Le contrôle `scripts/verifier-version.mjs` compare les deux fichiers npm et le tag `v<version>` dans les CI des sept applications.

## Livrables

- [README principal et clonage](../README.md), avec liens vers les huit dépôts.
- [Architecture](architecture.md) et [image](architecture.png), incluant applications, conteneurs, protocoles et stockage.
- [Documentation API](api/README.md).
- [Scénario](validation-c2.md) et [résultats](rapport-validation.md).
- [Planification à compléter avec les données réelles](planification.md).

## Suivi des recommandations du contrôle 1

| Recommandation | Traitement / preuve |
|---|---|
| Unifier les deux mocks | Suppression des mocks runtime; une instance RealGatewayRuntime, testée, utilisée par Electron |
| Émettre chaque réception | private-message.created / room-message.created deviennent message-recu puis messages:nouveau |
| Latence configurable du mock | Sans objet dans la version réelle, aucun mode simulé maintenu |
| Séparer UI et transport | Transport dans runtime et IPC; logique pure testée; une orchestration de présentation reste dans les pages |
| Aligner tags et versions | Historique C1 documenté; prochaines versions bloquées en CI si incohérentes |
| Calendrier, assignations, communication et effectif | Encore à confirmer par l’équipe : ne pas présenter cette recommandation comme terminée |
| Notifications hors focus | Tests de préférences et du processus principal; affichage natif à démontrer sur le poste cible |
| Persister avant diffuser | Prisma puis Redis Pub/Sub puis Socket.IO; REST pour l’historique |
| Reconnexion | Demande explicite de relecture REST après socket authentifié; test de message manqué |
| Administration protégée | Rôle admin à la connexion et autorisations des services; test des créations refusées |

L’appellation RealGatewayRuntime joue le rôle de l’ApiChatGateway demandé. Les vues utilisent le pont IPC; il n’est pas nécessaire de renommer la classe pour prouver l’usage de l’API réelle. Le contrat TypeScript AuthGateway ne couvre aujourd’hui que la connexion; le contrat complet est documenté et testé via le runtime et les pages.
