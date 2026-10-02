# Chatvardage — Dashboard d’administration

Panneau AdminJS réel, protégé par le rôle admin et connecté directement aux services métier.

## Démarrer le projet

1. Installer les dépendances :

```bash
npm --prefix dashboard-chatvardage install
```

2. Créer le fichier `.env` à partir du modèle, puis y générer `COOKIE_SECRET` et `SESSION_SECRET` (deux valeurs distinctes, `openssl rand -hex 32`) :

```bash
cp dashboard-chatvardage/.env.example dashboard-chatvardage/.env
```

`.env` est chargé par `dotenv` au tout début de `main.ts`, avant la lecture des secrets.

En production, `COOKIE_SECRET` doit être un secret aléatoire d’au moins 32 caractères.
`SESSION_SECRET` doit aussi être un secret aléatoire distinct d’au moins 32 caractères.
En développement local, les deux secrets sont générés séparément si les variables
sont absentes.

3. Démarrer le serveur :

```bash
npm --prefix dashboard-chatvardage run start:dev
```

Le serveur individuel écoute sur `http://localhost:3000`; définir un autre PORT si le Gateway occupe déjà 3000. Infra publie Dashboard sur 3002.

## Panneau d'administration

Le panneau est disponible sur `http://localhost:3002/administration` avec Infra (port 3000 en lancement individuel). Il utilise
le service Authentification pour la connexion et refuse les comptes dont le rôle
n'est pas `admin`.

Une fois connecté, il permet de créer, lister et supprimer les utilisateurs, les
salons et les messages. La liste des messages réunit tous les DM et tous les
messages de salon, affichés par pages dans AdminJS. Les opérations sont relayées aux
services propriétaires; le dashboard ne contient ni base de données ni données
simulées.

AdminJS est monté avec `@adminjs/express` sur l’adaptateur Express de Nest, car
ses ressources personnalisées relaient les requêtes vers les microservices.
AdminJS authentifie ses routes par le service Authentification; les guards,
interceptors et filtres propres aux contrôleurs Nest ne s’appliquent pas à ces
routes. L’application n’utilise pas de guards globaux. Toute future politique
globale doit couvrir explicitement les routes AdminJS.

`RessourceApiDistante` implémente l’interface `BaseResource` d’AdminJS; ses
méthodes `databaseName()` et `update()` sont requises par cette interface, même
si le dashboard ne possède pas de base locale et délègue les écritures.

`allowScripts` dans `package.json` autorise le script d’installation d’esbuild,
dont le binaire natif est requis par le bundler AdminJS. Le Dockerfile autorise
également explicitement les scripts npm durant les installations.

| Action | Service et routes utilisées |
| --- | --- |
| Connexion | Authentification: `POST /api/auth/login` |
| Utilisateurs | Authentification: `GET/POST /api/users`, `PATCH /api/users/:id/role` (compte créé comme administrateur), `DELETE /api/users/:id` |
| Serveurs | Room-Service: `GET /api/admin/servers`, `GET /api/servers/:id`, `POST /api/servers`, `DELETE /api/servers/:id` |
| Salons | Room-Service: `POST /api/servers/:id/channels`, `DELETE /api/channels/:id` |
| Messages privés | Message-Service: `GET /api/messages/admin?limit=100&cursor=`, `POST /api/messages/admin`, `DELETE /api/messages/admin/:id` |
| Messages de salon | Message-Service: `GET /api/messages/rooms/:channelId/history?limit=100&cursor=`, `POST /api/messages/rooms/:channelId/admin`, `DELETE /api/messages/rooms/:channelId/:id` |

### Pagination des messages

Message-Service renvoie au plus 100 messages par appel, avec un curseur
(`cursor` = identifiant du plus ancien message déjà reçu). Le Dashboard suit
ces curseurs jusqu’à une page incomplète, pour les DM comme pour chaque salon,
puis AdminJS découpe la liste complète en pages, avec le tri et les filtres.
Par chargement, une source (les DM, ou un salon) est plafonnée à 50 pages,
soit 5 000 messages ; au-delà, un avertissement est journalisé.

### Limites connues

Le dashboard charge les messages de chaque salon séparément, par lots d’au plus
cinq salons simultanément. La suppression d’un message charge aussi les
enregistrements pour retrouver son salon. Les API actuelles n’offrent pas de
lecture groupée ni de recherche directe commune par identifiant; réduire ces
chargements demande une évolution compatible de Message-Service.

Les listes réutilisent leurs résultats pendant une seconde afin d’éviter de
refaire le même chargement pour `count` puis `find`. La suppression d’un message
recherche encore son salon dans les enregistrements chargés; une API propriétaire
de lecture par identifiant éviterait ce parcours.

La liste des serveurs est chargée par pages de 100, jusqu’à 50 pages
(5 000 serveurs). Au-delà, le chargement s’arrête avec un avertissement dans
les journaux : une pagination côté AdminJS serait alors nécessaire.

### Dépendances et audit

La CI du dépôt Dashboard (`.github/workflows/ci.yml`) exécute
`npm audit --audit-level=high` sur toutes les dépendances, dev comprises.
`npm audit` ne signale aucune vulnérabilité haute ou critique ; il reste des
avis de sévérité modérée ou faible.

Ces avis ([GHSA-cp6q-959q-f8rh](https://github.com/advisories/GHSA-cp6q-959q-f8rh),
modéré, sur `@tiptap/core`, et [GHSA-vhrc-hgrq-x75r](https://github.com/advisories/GHSA-vhrc-hgrq-x75r),
faible, sur `@tiptap/extension-link`) viennent de `@tiptap/*` 2.1.13, épinglé par
`@adminjs/design-system` 4.1.1 (dépendance d’`adminjs` 7.8.17, dernière
version publiée). Le correctif exige tiptap 3.30.4 ou plus, incompatible avec
cette version du design system ; `npm audit fix --force` ne propose qu’une
rétrogradation vers `adminjs` 6.

Le `package.json` force certaines versions avec `overrides` :
`i18next-http-backend` 3, `uuid` 11 et `react-router`/`react-router-dom`
7.18.4 sous `adminjs`, `tinymce` 8 sous `@adminjs/design-system`, et
`minimatch` ^9.0.9 sous `@typescript-eslint/typescript-estree`.
`typescript-estree` 6.x épingle `minimatch` 9.0.3, vulnérable (sévérité haute) ;
cet override est temporaire et sera retiré lors du passage à typescript-eslint 8.

Retiré le 2 octobre 2026 (commit `Chatvardage/A26_5A6_01-Dashboard@f352e2a`, « fix audit ») : l’override
`@tiptap/*` 3.31.4 et le patch `patch-package` qui adaptait
`@adminjs/design-system` à Tiptap 3. Ils ne changeaient pas le bundle
précompilé servi au navigateur (voir la limite ci-dessous). `@adminjs/express`
n’est plus figé : il est en 6.1.1, sans avis connu à ce jour. Sa
compatibilité avec `adminjs` 7.8.17 est vérifiée par le test
`src/adminjs-express.spec.ts` du Dashboard (`buildAuthenticatedRouter` exposé
sur l’import par défaut utilisé par `main.ts`).

**Limite** : ces `overrides` changent l’arbre `node_modules`, mais pas le code
envoyé au navigateur. AdminJS sert
`@adminjs/design-system/bundle.production.js`
(`/frontend/assets/design-system.bundle.js`), un bundle précompilé qui
embarque ses propres copies : il contient toujours `tinymce` 6.8.2. Le risque
reste faible, car le Dashboard n’utilise pas l’éditeur riche (`richtext`),
seulement des champs `textarea`. Une vraie correction demande une version
d’AdminJS qui reconstruit ses bundles.

## Configuration

Le dashboard utilise les valeurs locales suivantes si les variables ne sont pas
définies :

```env
PORT=3000
AUTH_SERVICE_URL=http://localhost:3001
ROOM_SERVICE_URL=http://localhost:3003
MESSAGE_SERVICE_URL=http://localhost:3004
```

En environnement conteneurisé, remplacer les hôtes par les noms de service du
réseau Docker.

## Vérifications

Depuis la racine du dépôt :

```bash
npm --prefix dashboard-chatvardage run build
npm --prefix dashboard-chatvardage test -- --runInBand
npm --prefix dashboard-chatvardage run test:cov -- --runInBand
npm --prefix dashboard-chatvardage exec -- eslint "dashboard-chatvardage/src/**/*.ts"
```

Le rapport HTML est généré dans `dashboard-chatvardage/coverage/lcov-report/index.html`.
