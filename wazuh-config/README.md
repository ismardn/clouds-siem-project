# Configurations sur-mesure Wazuh (Blue Team)

Ce dossier regroupe l'ensemble du code de détection personnalisé, de décodage et de visualisation développé spécifiquement pour le SOC du projet CLOUDS. Ces fichiers transforment l'installation Wazuh par défaut en une véritable plateforme XDR adaptée à notre infrastructure.

## Arborescence du dossier

```text
wazuh-config/
 ├── dashboards/
 │    └── soc-main-dashboard.ndjson
 ├── decoders/
 │    └── local_decoder.xml
 └── rules/
      └── local_rules.xml
```

## Contenu et déploiement

Dans le cadre de notre architecture finale conteneurisée (Phase 3), ces fichiers de configuration ne sont pas copiés manuellement. Ils sont injectés dynamiquement dans les conteneurs Wazuh (Master et Worker) grâce au mécanisme de **Volumes Docker** défini dans le fichier `docker-compose.yml`.

### 1. Décodeurs (`/decoders/local_decoder.xml`)
Contient le décodeur sur-mesure permettant au SIEM de comprendre et de parser le format JSON des alertes réseaux provenant de l'IDS Suricata (via OPNsense).
*   **Décodeur `suricata_opnsense` :** Intercepte les événements Syslog entrants dont le nom de programme source est identifié par l'expression régulière `^suricata`.
*   **Déploiement Docker :** Montage par volume vers le chemin interne `/var/ossec/etc/decoders/local_decoder.xml`.

### 2. Règles de corrélation (`/rules/local_rules.xml`)
Contient l'ingénierie de détection (Detection Engineering) :
*   Règles de corrélation temporelle (Brute-Force DVWA).
*   Détection d'exécution de commandes (Suspicion RCE / WebShell via Auditd).
*   Capture des signatures Suricata décodées.
*   **Déploiement Docker :** Montage par volume vers le chemin interne `/var/ossec/etc/rules/local_rules.xml`.

### 3. Tableau de bord (`/dashboards/soc-main-dashboard.ndjson`)
Export complet du tableau de bord personnalisé centralisant les KPIs (Alertes critiques, actions de blocage, origine des attaques, intégration VirusTotal).
*   **Mode de déploiement :** À importer manuellement via l'interface Web (Menu principal > Management > Stack Management > Saved Objects > Import).