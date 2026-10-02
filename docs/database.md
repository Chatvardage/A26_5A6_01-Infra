# Bases de données

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

## Schémas métier de référence

Instantané des modèles Prisma au 1er octobre 2026. Les migrations SQL des dépôts propriétaires restent exécutables et font autorité (notamment l’index fonctionnel de courriel Auth). Aucune clé étrangère ne traverse les bases.

### Authentification

[Source et migrations](https://github.com/Chatvardage/A26_5A6_01-Authentification/tree/develop/prisma)

```prisma
model Utilisateur {
  // `dbgenerated("gen_random_uuid()")`, pas `@default(uuid())` : ce dernier
  // génère l'UUID côté client Prisma, jamais appelé au runtime dans ce
  // service (voir en-tête de fichier) — la colonne aurait alors une
  // contrainte NOT NULL sans aucune valeur par défaut côté PostgreSQL, et
  // l'INSERT de src/infrastructure/pg_utilisateur_repository.rs (qui ne
  // fournit pas `id`) échouerait. `gen_random_uuid()` est une fonction
  // native de PostgreSQL depuis la version 13, aucune extension requise.
  id                 String   @id @default(dbgenerated("gen_random_uuid()")) @db.Uuid
  pseudo             String   @unique
  // ⚠️ `@unique` déclare ici un index btree standard (sensible à la
  // casse) — mais la migration `index_courriel_insensible_a_la_casse`
  // (prisma/migrations/) l'a remplacé en base par un index UNIQUE
  // fonctionnel sur LOWER(courriel), pour que l'unicité soit garantie
  // par PostgreSQL indépendamment de la discipline applicative
  // (AuthService normalise déjà en minuscules avant chaque écriture —
  // voir pg_utilisateur_repository.rs). Prisma ne modélise pas les index
  // fonctionnels/expression : cette annotation reste donc « fausse » au
  // sens strict (documentation seulement) — ne pas relancer `prisma
  // migrate dev` sur ce modèle sans relire attentivement le SQL généré,
  // qui pourrait proposer de revenir à un index standard sur `courriel`.
  courriel           String   @unique
  mot_de_passe_hache String
  version_auth       Int      @default(0)
  role               String   @default("utilisateur")
  // `@db.Timestamptz` (avec fuseau) sur les deux colonnes : le code Rust
  // lit ces colonnes dans `chrono::DateTime<Utc>` (voir
  // src/domain/utilisateur.rs), qui correspond au type PostgreSQL
  // `timestamptz` — pas `timestamp` (le défaut de Prisma pour `DateTime`
  // sans cette annotation), qui se décoderait comme `NaiveDateTime` côté
  // SQLx et ferait échouer chaque requête à l'exécution.
  //
  // Pas de `@updatedAt` sur `modifie_le` : cette directive Prisma ne met à
  // jour la colonne que via le client Prisma (jamais appelé ici, voir
  // en-tête de fichier) — sans effet côté base de données. `modifie_le`
  // a donc un simple défaut `now()` comme `cree_le`, et c'est le SQL de
  // `pg_utilisateur_repository.rs` qui la remet à jour explicitement
  // (`SET modifie_le = now()`) à chaque UPDATE.
  cree_le            DateTime @default(now()) @db.Timestamptz
  modifie_le         DateTime @default(now()) @db.Timestamptz

  // Créé par la migration `index_utilisateurs_cree_le` (GET /api/users trie
  // par cree_le DESC) : déclaré ici pour que Prisma ne propose pas de le
  // supprimer.
  @@index([cree_le(sort: Desc)], map: "utilisateurs_cree_le_idx")
  @@map("utilisateurs")
}
```

### Room-Service

[Source et migrations](https://github.com/Chatvardage/A26_5A6_01-Room-Service/tree/develop/prisma)

```prisma
enum ServerRole {
  membre
  moderateur
}

enum ChannelAccess {
  tous
  moderateurs
}

enum ChannelWrite {
  tous
  moderateurs
}

model Server {
  id          String             @id @default(uuid())
  name        String
  // Image en data URL (même format que l'avatar de User-Config-Service).
  icon        String?
  // null uniquement pour le serveur par défaut « Chatvardage », géré par
  // les administrateurs globaux (voir src/servers/default-server.ts).
  ownerId     String?
  isPublic    Boolean            @default(false)
  isDefault   Boolean            @default(false)
  createdAt   DateTime           @default(now())
  updatedAt   DateTime           @updatedAt
  members     ServerMember[]
  invitations ServerInvitation[]
  channels    Room[]

  @@index([ownerId])
  @@index([isPublic])
}

model ServerMember {
  serverId String
  userId   String
  role     ServerRole @default(membre)
  joinedAt DateTime   @default(now())
  server   Server     @relation(fields: [serverId], references: [id], onDelete: Cascade)

  @@id([serverId, userId])
  @@index([userId])
}

model ServerInvitation {
  serverId  String
  userId    String
  invitedBy String
  invitedAt DateTime @default(now())
  server    Server   @relation(fields: [serverId], references: [id], onDelete: Cascade)

  @@id([serverId, userId])
  @@index([userId])
}

model Room {
  id          String        @id @default(uuid())
  serverId    String
  name        String
  position    Int           @default(0)
  access      ChannelAccess @default(tous)
  writePolicy ChannelWrite  @default(tous)
  createdBy   String?
  createdAt   DateTime      @default(now())
  updatedAt   DateTime      @updatedAt
  server      Server        @relation(fields: [serverId], references: [id], onDelete: Cascade)

  @@index([serverId, position])
}
```

### Message-Service

[Source et migrations](https://github.com/Chatvardage/A26_5A6_01-Message-Service/tree/develop/prisma)

```prisma
model PrivateMessage {
  id          String   @id @default(uuid())
  senderId    String
  recipientId String
  content     String
  createdAt   DateTime @default(now())
  updatedAt   DateTime @updatedAt

  @@index([senderId, recipientId, createdAt])
  @@index([recipientId, senderId, createdAt])
}

model RoomMessage {
  id        String   @id @default(uuid())
  roomId    String
  authorId  String
  content   String
  createdAt DateTime @default(now())
  updatedAt DateTime @updatedAt

  @@index([roomId, createdAt])
}
```

### User-Config-Service

[Source et migrations](https://github.com/Chatvardage/A26_5A6_01-User-Config-Service/tree/develop/prisma)

```prisma
enum Theme {
  sombre
  clair
}

enum Langue {
  fr
  en
}

enum StatutPresence {
  enLigne
  horsLigne
}

enum ModeNotification {
  systeme
  discret
  aucune
}

model ConfigUtilisateur {
  idUtilisateur    String            @id
  alias            String?
  theme            Theme             @default(sombre)
  langue           Langue            @default(fr)
  statutPresence   StatutPresence    @default(horsLigne)
  vuLaDerniereFois DateTime?
  modeNotification ModeNotification  @default(systeme)
  // Image de profil en data URL (PNG/JPEG/WebP en base64), déjà
  // redimensionnée côté Frontend — voir MettreAJourConfigDto.avatar.
  avatar           String?
  creeLe           DateTime          @default(now())
  misAJourLe       DateTime          @default(now()) @updatedAt
}
```
