# Rapport de validation

Validation locale du 1er octobre 2026, depuis les révisions de développement. Les résultats ci-dessous distinguent les vérifications exécutées des éléments restant à démontrer.

## Vérifications automatisées

| Application | Résultat |
|---|---|
| Frontend | 225 tests; couverture de 100 % sur le périmètre configuré; types, lint et build réussis |
| Dashboard | 76 tests; couverture de 100 %; types, lint, build et bundle AdminJS réussis |
| Authentification | 160 tests; format, Clippy et build release réussis; couverture des lignes de 99,01 % |
| Room-Service | 196 tests unitaires et 14 tests e2e; couverture de 100 % |
| Message-Service | 291 tests unitaires; couverture de 100 % |
| User-Config-Service | 83 tests unitaires et 24 tests e2e; couverture de 100 % |
| Serveur-API | 135 tests unitaires et 6 tests e2e; couverture de 100 % |

Les vérifications npm de compilation et de lint des services passent. Les couvertures reflètent les exclusions et seuils de chaque dépôt; elles ne signifient pas que toutes les interactions système sont couvertes. Le test des notifications exécute le module principal avec Electron simulé.

Les sept vérificateurs de versions acceptent le tag correspondant et rejettent un tag incohérent. Les workflows passent actionlint et les cinq scripts shell Infra passent ShellCheck. L’audit des dépendances de production Dashboard ne signale aucune vulnérabilité critique, mais conserve 38 modérées et une élevée : leur résolution reste à évaluer avec les dépendances AdminJS. L’audit Message-Service ne signale aucune vulnérabilité.

## Stack et intégration réelle

Une stack Docker isolée a été construite depuis les sources avec des volumes vierges, des ports locaux attribués automatiquement et un secret de session temporaire. Les ressources de la stack habituelle sont préservées.

- Construction et démarrage des neuf conteneurs réussis; PostgreSQL, Redis, les services et le Dashboard sont en santé.
- Connexion SQL vérifiée à chacune des quatre bases. Migrations appliquées : Authentification 4, Room 3, Message 3, Configuration 3.
- Le healthcheck réussit avec la stack complète et échoue lorsque le Dashboard est arrêté; il réussit de nouveau après restauration.
- Deux clients Socket.IO authentifiés reçoivent le même DM; lecture REST, modification et suppression vérifiées.
- Un message envoyé pendant une déconnexion revient dans l’historique REST après reconnexion. Le test de page du desktop vérifie aussi le déclenchement de la relecture et l’affichage du message manqué.
- Historique et configuration conservés après redémarrage de PostgreSQL, Redis et des services.
- Accès administrateur refusé à un utilisateur ordinaire; accès anonyme au Dashboard redirigé vers la connexion.
- L’action réelle AdminJS de création renvoie une erreur pour un courriel déjà utilisé, sans redirection de réussite. Une création valide réussit.
- Suppression d’un utilisateur, d’un salon et d’un message par les actions du Dashboard vérifiée auprès des API; refus des opérations non autorisées vérifié.

## Portée et vérifications complémentaires

- Vérifier les notifications natives hors focus avec deux fenêtres Electron sur chaque système cible. Les clients réseau automatisés ne remplacent pas cette observation.
- Valider les installateurs desktop sur les plateformes supportées. Une compilation locale réussie ne prouve pas leur installation sur chaque système.
- Vérifier les exécutions GitHub Actions après publication des commits et des tags. Les résultats décrits ici proviennent de validations locales.

Le [scénario fonctionnel](validation.md) décrit les manipulations reproductibles; le [guide des versions](versions.md) décrit les règles de publication. Ce rapport consigne un état daté et ne garantit pas les révisions ultérieures.
