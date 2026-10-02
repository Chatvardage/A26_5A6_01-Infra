# Validation fonctionnelle et intégration

## Principe

Une commande réussie est une preuve uniquement pour la révision et l’environnement testés. Les suites unitaires qui simulent Prisma/Redis ne remplacent pas le scénario intégré. Les notifications natives et le rendu Electron doivent être observés sur le poste cible.

## Installation propre, sans effacer les données de travail

Cloner les huit révisions à valider dans un dossier distinct. Générer une configuration Compose de validation avec un nom de projet différent, des noms de conteneurs/réseaux uniques, des volumes neufs et des ports libres. Le `container_name` et le nom du réseau du Compose racine étant fixes, **`-p` seul ne suffit pas** à isoler deux stacks.

Suivre exactement le README (secret de session inclus), construire les images, attendre les healthchecks, puis contrôler :

```bash
docker compose config -q
docker compose up --build -d --wait --wait-timeout 240
docker compose ps./scripts/healthcheck.sh
docker compose logs --no-color --tail=100 postgres redis
```

Vérifier les migrations sur les quatre bases neuves. Redémarrer sans supprimer les volumes et confirmer la conservation des données. Supprimer uniquement les volumes de validation après les essais. Ne jamais utiliser `down -v` sur la stack de travail pour ce contrôle.

## Scénario fonctionnel

| Étape | Manipulation | Résultat attendu |
|---|---|---|
| 1 | Démarrer la stack depuis les README | Tous les services requis sains, quatre bases accessibles, Redis PONG |
| 2 | Ouvrir deux profils Electron; créer A et B | Comptes distincts, connexion réelle via Gateway |
| 3 | Changer alias/thème/langue de A | UI adaptée; mêmes valeurs après relance |
| 4 | A envoie un DM à B | Un seul message chez A et B; événement temps réel |
| 5 | Modifier puis supprimer un DM | Historique et événement cohérents des deux côtés |
| 6 | Déconnecter le socket B; A envoie/modifie/supprime | Au retour de B, REST rattrape l’état sans attendre un nouveau message |
| 7 | Redémarrer les services sans supprimer les volumes | Comptes, configuration et historique conservés |
| 8 | Ouvrir Dashboard sans session, puis avec un compte standard | Connexion demandée; utilisateur non-admin refusé |
| 9 | Admin liste et supprime un utilisateur, un salon jetable et un message | Suppressions réelles; routes interdites à un compte standard |
| 10 | Admin crée un compte avec un courriel déjà utilisé | Erreur visible, aucun faux succès, formulaire conservé |
| 11 | B reçoit un DM avec sa fenêtre hors focus | Notification native ou repli annoncé; clic ouvre la bonne conversation |
| 12 | Mettre le mode notifications à aucune | Aucune notification système |

Utiliser des comptes et salons jetables pour les suppressions. La suppression du dernier salon et celle du serveur par défaut sont volontairement refusées.

## Résultats

Les résultats datés et les limites sont consignés dans [le rapport de validation](rapport-validation.md). Un élément non exécuté reste explicitement « à démontrer ».
