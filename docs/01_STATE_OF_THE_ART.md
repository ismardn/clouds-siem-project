# État de l'art et justification des choix technologiques

Ce document expose les réflexions architecturales menées lors de la conception du projet CLOUDS et justifie l'ensemble des choix technologiques (Cloud, SIEM, réseau) retenus pour son déploiement.

---

## 1. Contexte et raison d'être du projet

Le projet CLOUDS définit une étude progressive pour la conception et le déploiement d'une plateforme SIEM (Security Information and Event Management) et XDR (Extended Detection and Response). Si des solutions commerciales existent sur le marché (Splunk, Microsoft Sentinel, IBM QRadar), le déploiement d'une architecture open-source répond à des limites critiques inhérentes aux offres propriétaires.

**Limites des solutions propriétaires contournées par ce projet :**
* **Maîtrise du coût total de possession (TCO) :** Les solutions commerciales facturent selon le volume de données ingérées, rendant le passage à l'échelle très coûteux.
* **Indépendance technologique (vendor lock-in) :** Une architecture open-source garantit la transparence, l'absence d'enfermement propriétaire et s'aligne sur les valeurs de partage des connaissances de la communauté cybersécurité.
* **Agnosticisme et hétérogénéité :** Le système doit assurer une surveillance centralisée intégrant de multiples sources hétérogènes (Windows, Linux, équipements réseau).

Ces contraintes justifient le choix d'une stack 100% open-source, auditée, réplicable et évolutive, structurée en trois phases progressives.

---

## 2. Infrastructure : Cloud public vs on-premise et ingénierie FinOps

Le projet évolue d'une architecture centralisée simple vers une solution d'entreprise conteneurisée et hautement disponible. L'hébergement sur le Cloud s'impose face au modèle sur site (on-premise) pour des raisons de scalabilité, de travail collaboratif et de capacités réseau avancées (répartition de charge native, VPC managés). De plus, le Cloud permet la simple reproductibilité et l'industrialisation de la solution.

### 2.1 Analyse comparative des fournisseurs cloud

| Fournisseur Cloud | Analyse pour CLOUDS | Bilan |
| :--- | :--- | :--- |
| **Microsoft Azure** | Bonne intégration, mais quotas étudiants très restrictifs - blocages fréquents lors du provisionnement multi-régions. | ❌ Écarté (risque de blocage technique) |
| **Amazon Web Services (AWS)** | Leader du marché, mais le modèle de facturation complexe présente un risque élevé de dépassement budgétaire. | ❌ Écarté (risque financier) |
| **Google Cloud Platform (GCP)** | Interface intuitive, gestion réseau VPC performante, allocation de crédits généreuse (300 $) permettant de maquetter les trois phases sans restriction de ressources. | ✅ **Solution retenue** |

GCP offre le meilleur équilibre entre disponibilité de crédits, richesse des services managés (GKE, Cloud Load Balancing) et simplicité de gestion réseau, des critères décisifs pour les phases 2 et 3. L'infrastructure peut être décrite comme du code, versionnée et redéployée à l'identique en quelques minutes.

### 2.2 Stratégie FinOps et topologie hybride

Afin de préserver l'enveloppe de crédits GCP, des choix d'architecture spécifiques ont été arrêtés :
* **Dimensionnement des disques :** Utilisation de disques SSD "avec équilibrage" pour les instances critiques (SIEM, Windows Server et pare-feu OPNsense) afin d'assurer performance et réactivité, et maintien de disques durs standard (HDD) économiques uniquement pour le serveur Web Ubuntu.
* **Topologie hybride (simulation de menace) :** L'attaquant (Kali Linux) n'est pas hébergé dans le Cloud. Il opère en local depuis le poste physique pour attaquer l'IP publique de la passerelle GCP, simulant ainsi une véritable attaque externe sans surcoût d'hébergement.
* **Extinction planifiée :** Mise en place d'une politique `resource-policies` avec Cloud Scheduler pour automatiser l'arrêt complet de l'infrastructure en dehors des heures de travail.

---

## 3. Cœur de la solution SIEM/XDR et gouvernance de la donnée

L'objectif est de sélectionner une plateforme open-source capable d'évoluer d'un nœud unique vers une architecture distribuée multi-nœuds, tout en assurant la conformité avec des réglementations strictes (RGPD, ISO/IEC 27001, HIPAA, PCI DSS).

### 3.1 Analyse comparative SIEM/XDR

| Critère | Wazuh (Retenu) | Elastic Security (ELK) | Security Onion |
| :--- | :--- | :--- | :--- |
| **Modèle & Coûts** | 100% gratuit, toutes fonctionnalités XDR et clustering incluses. | Freemium - ML et XDR complet nécessitent une licence payante. | Gratuit, mais assemblage complexe de multiples outils (Zeek, Suricata). |
| **Consommation (GCP)** | ✅ Optimisée. Agent et serveur central légers, idéal pour budget maîtrisé. | ❌ Lourde. Elasticsearch exige énormément de RAM. | ❌ Très lourde. Grande capacité matérielle requise. |
| **Conformité & Normes** | Native. Tableaux de bord automatiques : RGPD, HIPAA, PCI DSS. | Manuelle - règles personnalisées à créer pour chaque norme. | Orientée réseau, moins adaptée aux audits de conformité ITIL. |
| **Évolutivité (Phases)** | ✅ Transition fluide nœud unique ➡️ cluster Docker (Docker Compose). | ⚠️ Conteneurisation complexe sans licence Enterprise. | ❌ Architecture difficile à scinder en micro-services (Phase 3). |

Wazuh s'impose comme la solution de référence pour ce projet : gratuit, léger, conforme nativement aux réglementations et conçu pour évoluer vers une architecture distribuée.

### 3.2 Gestion du cycle de vie des logs

Pour organiser les preuves (forensics) en cas d'incident et éviter un engorgement du système, le projet s'appuie sur le mécanisme de rotation natif du manager Wazuh :
* **Rotation journalière :** Chaque jour à minuit, les journaux d'alertes sont automatiquement clôturés et isolés dans des fichiers horodatés (ex : `ossec-alerts-18.json`).
* **Isolation et archivage :** Cette organisation cloisonnée par mois et par jour permet d'exporter facilement les preuves vers un stockage froid ou de purger les mois obsolètes par de simples scripts, sans jamais impacter le moteur de détection en temps réel.

---

## 4. Sécurité périphérique et routage

Le cahier des charges impose la surveillance d'un pare-feu communiquant via syslog et sans agent. Ce composant doit également simuler le routage d'un réseau d'entreprise.

| Critère | OPNsense (Retenu) | pfSense (CE/Plus) | Iptables / UFW |
| :--- | :--- | :--- | :--- |
| **Coûts Cloud** | Gratuit. Import d'images personnalisées sur GCP facilité par la communauté (support cloud-init), sans surcoût. | ❌ Risque de coûts cachés. Version Plus payante (Marketplace). Import CE bloquant sur KVM. | Gratuit et natif. Cependant, pas de pare-feu applicatif. |
| **API & Automatisation** | API REST native - atout majeur pour automatiser la réponse aux incidents (Phase 3). | ⚠️ API moins mature, freine l'automatisation en Phase 3. | ❌ Gestion en CLI uniquement - aucune API. |
| **Surveillance réseau** | ✅ Interface graphique, tableaux de bord réseau, intégration syslog native. | Bon candidat, architecture vieillissante côté hyperviseur cloud. | ❌ Insuffisant - aucune vision globale des menaces réseau. |

OPNsense est retenu pour son API REST native, son déploiement sans friction sur GCP et sa roadmap active.

---

## 5. Système d'exploitation et alerting

### 5.1 Choix de l'OS Linux

Le choix de l'OS est critique, tant pour héberger le serveur central Wazuh que pour les machines cibles.

| Distribution | Analyse pour CLOUDS | Bilan |
| :--- | :--- | :--- |
| **Debian 12** | Extrêmement stable et léger. Installations manuelles nécessaires pour les outils récents. | Bon candidat, mais demande plus de maintenance. |
| **Rocky / AlmaLinux 9** | Intègrent nativement SELinux. Excellents pour une approche haute sécurité. | Courbe d'apprentissage raide pour la configuration réseau. |
| **Ubuntu Server 24.04 LTS** | Standard absolu sur les clouds publics (GCP). Support LTS, documentation massive et outils (Wazuh, Docker) documentés en priorité. | ✅ **Solution retenue** - meilleur ratio stabilité / facilité. |

Ubuntu Server LTS garantit une intégration sans friction avec les instances GCP et minimise les erreurs de dépendances lors des déploiements automatisés.

### 5.2 Système d'alerte et notification (phases 2 et 3)

La mise en place d'un système de notification en temps réel est exigée pour alerter l'équipe SecOps.

| Solution | Analyse pour CLOUDS | Bilan |
| :--- | :--- | :--- |
| **Email/SMTP** | Port 25 bloqué sur GCP. Génère une "fatigue d'alerte" menant à l'ignorance des messages. | ❌ Écarté (bloqué + fatigue d'alerte) |
| **Discord** | Solution orientée gaming, non adaptée aux exigences d'un contexte corporate. | ❌ Écarté (contexte non professionnel) |
| **Microsoft Teams** | Connecteurs O365 supprimés, intégration complexe et dépendance aux licences. | ❌ Écarté (webhooks dépréciés) |
| **Slack** | Standard DevSecOps moderne, 100% gratuit. Intégration webhook avec Wazuh native et gestion structurée. | ✅ **Solution retenue** |

---

## 6. Synthèse de l'architecture

| Domaine | Solution retenue | Principale justification |
| :--- | :--- | :--- |
| **Infrastructure Cloud** | Google Cloud Platform (GCP) | Crédits généreux, VPC performant, services managés natifs. |
| **Plateforme SIEM/XDR** | Wazuh | 100% gratuit, conformité native RGPD/HIPAA, scalable. |
| **Pare-feu / Routage** | OPNsense | API REST native, déploiement GCP sans friction, stable. |
| **OS Serveurs Linux** | Ubuntu Server 24.04 LTS | Standard cloud GCP, support LTS, écosystème Wazuh prioritaire. |
| **Indexation / Stockage** | OpenSearch | Moteur intégré nativement à Wazuh pour une recherche rapide. |
| **Conteneurisation** | Docker Compose | Infrastructure as Code (IaC), légèreté, adaptation parfaite à l'échelle du projet. |
| **Répartition de charge** | NGINX (Conteneurisé) | Intégré nativement dans la stack Docker Compose, proxy inverse ultra-léger. |
| **Alerting / Notification** | Slack | Norme DevSecOps moderne, gratuit, simple à intégrer via webhooks. |

Cette architecture forme une base cohérente, évolutive et sans coût de licence logicielle, répondant aux standards industriels de sécurité et d'ingénierie Cloud.
