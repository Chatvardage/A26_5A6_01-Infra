# Bases de données — Contrôle 2

## Principe
Infra lance une seule instance PostgreSQL et crée quatre bases logiques avec un propriétaire distinct. **Les bases sont vides après l'initialisation d'Infra.** Chaque microservice applique ensuite ses propres migrations.

Chaque base est fermée aux autres comptes (`REVOKE CONNECT, TEMPORARY ... FROM PUBLIC`) : le compte d'un service ne peut ouvrir que **sa** base (par défaut, PostgreSQL laisse tout compte se connecter à toutes les bases). Seuls le propriétaire et le superutilisateur (Adminer) y accèdent. Comme tout le script d'initialisation, cela ne s'applique qu'à un volume neuf : sur un volume existant, `docker compose down -v` (efface les données) ou exécuter une fois `REVOKE CONNECT, TEMPORARY ON DATABASE <base> FROM PUBLIC;` pour chaque base en superutilisateur.

| Base | Propriétaire | Schéma métier géré par |
|---|---|---|
| `chatvardage_auth` | `auth_service` | Authentification |
| `chatvardage_rooms` | `room_service` | Room-Service |
| `chatvardage_messages` | `message_service` | Message-Service |
| `chatvardage_config` | `config_service` | User-Config-Service |

Les identifiants d'utilisateurs peuvent être référencés comme chaînes entre domaines, sans clé étrangère SQL entre deux bases de microservices.

## Pourquoi Infra ne crée pas les tables
Les migrations doivent vivre avec le code qui utilise les données. Cela évite deux sources de vérité pour le schéma et les erreurs Prisma `P3005` (« database schema is not empty ») lors du déploiement sur une base neuve.

## Pas de données de démonstration
Infra ne seede aucune donnée, et l'application n'a pas de mode simulé (mock) : toutes les données viennent des microservices. Les seules données créées automatiquement le sont par les migrations des services (par exemple le serveur par défaut et son message de bienvenue).

## Temps réel
PostgreSQL est la source de vérité. Redis Pub/Sub/WebSocket sert à diffuser les événements après persistance réussie. Après reconnexion, le client récupère l'état durable via REST. Les messages privés et de salon sont réels et persistés par Message-Service.
