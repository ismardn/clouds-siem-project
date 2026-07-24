# Déploiement du SIEM (Wazuh & OpenSearch)

Ce dossier contient les manifestes `docker-compose` et les configurations (NGINX, certificats, Wazuh) pour déployer l'architecture XDR en haute disponibilité (cluster).

## Organisation des fichiers

```text
.
├── docker-compose.yml                 # Manifeste de déploiement (cluster haute disponibilité)
├── README.md                          # Ce fichier
└── config/                            # Fichiers de configuration montés dans les conteneurs
    ├── certs.yml                      # Définition pour la génération des certificats TLS
    ├── nginx/                         # Load balancer & reverse proxy HTTPS
    │   └── nginx.conf
    ├── wazuh_cluster/                 # Configuration des nœuds de traitement Wazuh
    │   ├── wazuh_manager.conf         # Nœud maître (master)
    │   └── wazuh_worker.conf          # Nœud de travail (worker)
    ├── wazuh_dashboard/               # Interface web UI
    │   ├── opensearch_dashboards.yml
    │   └── wazuh.yml
    └── wazuh_indexer/                 # Cluster de base de données OpenSearch (3 nœuds)
        ├── internal_users.yml         # Sécurité et authentification de la BDD
        ├── wazuh1.indexer.yml
        ├── wazuh2.indexer.yml
        └── wazuh3.indexer.yml
```

## Prérequis systèmes critiques

Wazuh Indexer (basé sur OpenSearch) nécessite une modification de la mémoire virtuelle du système hôte. Sur votre serveur Ubuntu/Debian, exécutez impérativement cette commande avant de lancer les conteneurs :

```bash
sudo sysctl -w vm.max_map_count=262144
```

*(Pour rendre ce changement permanent, ajoutez `vm.max_map_count=262144` dans `/etc/sysctl.conf`)*

## Démarrage rapide

1. Assurez-vous d'avoir installé `docker` et `docker-compose` (ou `docker compose`) sur la machine hôte.
2. Clonez ce dépôt et naviguez à l'intérieur de ce dossier :
    ```bash
    cd docker/
    ```
3. Démarrez l'ensemble du cluster en arrière-plan :
    ```bash
    docker-compose up -d
    ```
4. Patientez quelques minutes (le temps que le cluster OpenSearch élise son maître et que le dashboard se connecte à l'API).

## Accès aux services

Une fois les conteneurs démarrés, les services sont accessibles sur les ports suivants :
- **Wazuh dashboard (interface web) :** `https://<IP_DU_SERVEUR>` (port 443 via NGINX)
- **Agent enrollment :** port `1515` (TCP)
- **Agent connection (events) :** port `1514` (TCP via load balancer NGINX)
- **API Wazuh :** port `55000` (TCP)

> **Note :** Dans ce dépôt, les mots de passe et les certificats TLS ont été anonymisés. Avant le déploiement en production, générez vos propres certificats (via le script de génération officiel de Wazuh) et modifiez les identifiants par défaut dans le fichier `docker-compose.yml`.