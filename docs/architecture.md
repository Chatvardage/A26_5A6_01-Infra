# Architecture C2

```mermaid
flowchart LR
  FE[Frontend Electron] -->|HTTP + WebSocket| API[Serveur-API / Gateway]
  DASH[Dashboard / AdminJS] --> API
  API --> AUTH[Authentification]
  API --> ROOM[Room-Service]
  API --> MSG[Message-Service]
  API --> CFG[User-Config-Service]
  AUTH --> ADB[(auth_db)]
  ROOM --> RDB[(rooms_db)]
  MSG --> MDB[(messages_db)]
  CFG --> CDB[(config_db)]
  MSG --> REDIS[(Redis Pub/Sub)]
  REDIS --> API
  subgraph Infra
    PG[(PostgreSQL)]
    REDIS
    ADB
    RDB
    MDB
    CDB
  end
```

Le Dashboard est l'application AdminJS du dépôt `A26_5A6_01-Dashboard`; Infra orchestrera son conteneur lorsque l'intégration de tous les repos sera activée (il n'est pas encore dans `docker-compose.yml`). AdminJS n'est pas une responsabilité métier d'Infra.

Le service `adminer` (port `8080`) du Compose est distinct : c'est un outil générique d'inspection PostgreSQL réservé au développement, pas le Dashboard.
