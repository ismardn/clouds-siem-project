# Résolution des incidents et débogage

Ce document retrace les obstacles techniques majeurs rencontrés lors des différentes phases du projet CLOUDS et détaille les solutions (workarounds) mises en place.

---

## 1. Défis de l'ingénierie réseau (phase 1)

### 1.1 Le blocage des IP sources par le pare-feu GCP (routage Cloud DMZ)
* **Le problème :** Lors des tests d'attaque depuis l'extérieur vers le serveur DVWA, les paquets passaient le pare-feu OPNsense, mais n'atteignaient jamais le serveur Web. Le problème venait du pare-feu natif de GCP (VPC Firewall) : la règle `allow_internal_dmz` n'autorisait que la plage interne `10.0.0.0/16`. Puisque OPNsense transmettait les paquets à la DMZ en conservant l'IP publique d'origine de l'attaquant, l'hyperviseur GCP considérait ce trafic comme illégitime sur un sous-réseau privé et le détruisait avant même qu'il ne touche la VM cible.
* **La solution :** Plutôt que de masquer l'adresse source sur OPNsense (Source NAT), ce qui aurait gravement faussé les logs du SIEM en masquant la véritable adresse IP de l'attaquant, la règle de pare-feu GCP a été modifiée. Le paramètre `source-ranges` de la règle DMZ a été passé à `0.0.0.0/0`, autorisant ainsi le trafic relayé par OPNsense à atteindre sa cible tout en conservant l'intégrité de l'adresse IP source.

### 1.2 Le paradoxe de l'isolement initial (l'accès à OPNsense)
* **Le problème :** L'architecture sécurisée a posé un problème de "poule et d'œuf" lors du déploiement. OPNsense était la seule porte d'entrée, mais pour configurer les interfaces, le NAT et le VPN, il fallait accéder à son interface d'administration graphique (Web GUI) située côté LAN. Le tunnel WireGuard n'étant pas encore créé, il n'y avait aucun accès au réseau interne, rendant la machine totalement verrouillée de l'extérieur.
* **La solution :** L'utilisation de la console série de Google Cloud. En se connectant directement à l'interface en ligne de commande de la VM via le port série, la commande `pfctl -d` a été exécutée. Cela a désactivé temporairement le moteur de filtrage (Packet Filter) d'OPNsense. Cette action de sauvetage a permis d'accéder exceptionnellement à l'interface Web depuis l'IP publique, le temps de configurer le réseau, les règles de pare-feu et de monter le tunnel WireGuard pour reprendre le contrôle via un canal chiffré.

### 1.3 Superposition des couches de sécurité (filtrage multi-niveaux)
* **Le problème :** L'un des plus grands défis de la Phase 1 a été la courbe d'apprentissage liée à l'empilement des mécanismes de sécurité. Pour qu'un simple paquet ICMP (Ping) ou un log puisse transiter d'une VM à une autre, il devait franchir avec succès jusqu'à quatre barrières de contrôle différentes : les règles Ingress/Egress du VPC Firewall de GCP, les tables de routage personnalisées de l'hyperviseur, les règles de pare-feu d'OPNsense (par interface) et les règles de NAT. L'oubli d'une seule case à cocher dans l'une de ces quatre interfaces entraînait une destruction silencieuse du paquet, rendant le débogage extrêmement fastidieux.
* **La solution :** L'adoption d'une méthodologie de débogage stricte (Packet Tracing). Au lieu d'avancer à l'aveugle, il a fallu utiliser les outils d'analyse de trafic étape par étape : vérification des logs du pare-feu GCP, utilisation du `Live View` (Packet Filter) sur OPNsense pour vérifier l'arrivée et la traduction du paquet, et enfin l'utilisation de `tcpdump` directement sur les cibles Ubuntu pour confirmer la réception finale. Cette rigueur a permis de cartographier mentalement le flux réseau complet du Cloud.

---

## 2. Défis de la migration distribuée (phase 2)

### 2.1 Le transfert de la PKI (certificats) sans mot de passe
* **Le problème :** Lors de la création du cluster, le Manager devait distribuer l'archive `wazuh-install-files.tar` (contenant les certificats TLS) à l'Indexer et au Dashboard. Or, les VM GCP n'acceptent que les connexions par clé SSH, rendant la commande `scp` directe impossible entre les nœuds.
* **La solution :** Utilisation du poste physique de l'administrateur comme **machine de rebond**. L'archive a été rapatriée sur le PC via `scp -i cle.pem`, puis repoussée vers les autres nœuds avec cette même clé d'authentification.

### 2.2 Rejet des agents et crash du manager (Erreur 1202)
* **Le problème :** Après la migration, les agents Windows et Ubuntu n'arrivaient plus à se connecter (`Unable to add agent`). L'utilisation des balises `<force_insert>` dans la configuration a provoqué un crash fatal du Manager (Erreur 1202) en raison de conflits d'IP et de clés obsolètes.
* **La solution :** Suppression des balises dépréciées pour réanimer le service. Ensuite, exécution de la commande `truncate -s 0 client.keys` sur le Manager **et** sur les agents pour vider le trousseau. Au redémarrage, une négociation de clés neuves et propres a eu lieu.

### 2.3 L'incompatibilité des versions
* **Le problème :** Une fois les clés purgées, les logs affichaient `Incompatible version for new agent`. Le nouveau cluster Phase 2 avait été installé en version **4.9**, tandis que les agents de la Phase 1 étaient restés en **4.14.5** (le Manager doit toujours avoir une version supérieure ou égale aux agents).
* **La solution :** Mise à jour globale du cluster. Mise à niveau séquentielle de l'Indexer, du Manager et du Dashboard via `apt-get install --only-upgrade`.

### 2.4 L'amnésie du dashboard
* **Le problème :** Suite à la mise à jour `apt`, l'interface Web affichait `Wazuh dashboard server is not ready yet` (Erreur : `ConnectionRefused 127.0.0.1:9200`). Le processus d'upgrade avait écrasé le fichier de configuration, forçant le Dashboard à chercher la base OpenSearch sur sa propre machine locale (`localhost`).
* **La solution :** Édition du fichier `opensearch_dashboards.yml` pour y réinjecter l'IP réelle de l'Indexer (`10.0.3.11`) et redémarrage du service.

---

## 3. Défis de la conteneurisation (phase 3)

### 3.1 Saturation mémoire (crash OOM de l'indexer)
* **Le problème :** Lors du passage sur Docker Compose, le conteneur `wazuh.indexer` s'arrêtait systématiquement (Out Of Memory / crash).
* **La solution :** Les bases de données Elastic/OpenSearch exigent une allocation mémoire spécifique côté noyau Linux. Résolution en ajustant les paramètres du système hôte Ubuntu via la commande `sysctl -w vm.max_map_count=262144`.

### 3.2 L'aveuglement du load balancer (Active Response & IDS)
* **Le problème :** Avec l'introduction du Load Balancer NGINX, les logs entrants (notamment les flux Syslog d'OPNsense sur le port UDP 5140) étaient distribués aléatoirement sur le nœud `Master` ou `Worker`. Cela rendait la réception des événements Suricata et le déclenchement du script `firewall-drop` (Active Response) incertains.
* **La solution :** **Duplication asymétrique de la configuration.** Le bloc `<remote>` (pour écouter le Syslog d'OPNsense) et la déclaration de l'Active Response ont été injectés de manière identique dans `wazuh_manager.conf` **ET** `wazuh_worker.conf`. Le port Docker `5140:5140/udp` a également été explicitement ouvert vers le Worker pour percer la bulle réseau Docker.
