# CLOUDS : plateforme SIEM/XDR et architecture SOC cloud-native

![GCP](https://img.shields.io/badge/Google_Cloud-4285F4?style=for-the-badge&logo=google-cloud&logoColor=white)
![Terraform](https://img.shields.io/badge/Terraform-7B42BC?style=for-the-badge&logo=terraform&logoColor=white)
![Wazuh](https://img.shields.io/badge/Wazuh-005E8C?style=for-the-badge&logo=wazuh&logoColor=white)
![Docker](https://img.shields.io/badge/Docker-2CA5E0?style=for-the-badge&logo=docker&logoColor=white)
![Python](https://img.shields.io/badge/Python-3776AB?style=for-the-badge&logo=python&logoColor=white)

**CLOUDS** (*Cloud Logging, Orchestration and Unified Defense System*) est un Proof of Concept (PoC) complet d'une infrastructure de supervision de sécurité d'entreprise. Ce projet illustre la conception, le déploiement automatisé et l'exploitation d'un **SOC (Security Operations Center)** moderne, allant de l'ingénierie réseau Cloud (IaaS) jusqu'à la réponse automatisée aux incidents (SOAR).

![Architecture finale (phase 3)](architecture/architecture-phase3-containerized.png)

---

## Objectifs du projet

L'objectif de ce projet est de démontrer la viabilité d'une stack de sécurité **100% open-source**, évolutive et hautement disponible, capable de rivaliser avec des solutions propriétaires. 

Le projet a été développé selon une approche **DevSecOps** et **Purple Team**, intégrant à la fois la construction de l'infrastructure, la création de l'arsenal défensif, et la simulation d'attaques (Offensive Security) pour valider les mécanismes de détection.

### Fonctionnalités clés
* **Infrastructure as Code (IaC) & FinOps :** Provisionnement automatisé sur Google Cloud Platform (GCP) via Terraform, avec politiques de réduction des coûts (extinction nocturne automatisée).
* **Ingénierie réseau & sécurité périmétrique :** Cloisonnement strict en sous-réseaux (VPC-WAN, LAN, DMZ, SOC) routés et protégés par un pare-feu **OPNsense**.
* **Architecture distribuée & conteneurisée :** Déploiement de la solution SIEM/XDR **Wazuh** sous forme de cluster multi-nœuds via **Docker Compose**, équilibré par **NGINX**.
* **Détection multicouche (XDR) :** 
    * Réseau (NIDS) : Intégration de **Suricata** avec création de décodeurs JSON sur-mesure.
    * Endpoint (HIDS) : Détection de rootkits, surveillance d'intégrité (FIM) et analyse des appels systèmes via **Auditd**.
* **Threat Intelligence & SOAR :** Enrichissement automatique des alertes via l'API **VirusTotal**, notification en temps réel sur **Slack**, et blocage dynamique des attaquants au niveau pare-feu (Active Response).

---

## Supervision et tableau de bord

![Tableau de bord SOC](screenshots/wazuh_soc_main_dashboard.png)
*Vue centralisée du SOC mettant en évidence les métriques de blocage (Active Response) et les alertes critiques générées lors des simulations d'attaques.*

---

## Documentation détaillée

La documentation de ce projet a été rédigée avec la rigueur d'un environnement de production. Elle est divisée en quatre documents majeurs retraçant l'évolution de l'infrastructure et la stratégie de défense :

1. [**État de l'art et choix technologiques**](docs/01_STATE_OF_THE_ART.md) : Justification des choix architecturaux, comparatifs des solutions SIEM/Cloud et contraintes réglementaires.
2. [**Architecture et évolution de l'infrastructure**](docs/02_ARCHITECTURE_AND_EVOLUTION.md) : Récit du déploiement progressif, du nœud monolithique (IaaS) jusqu'au cluster haute disponibilité (CaaS).
3. [**Détection et réponse aux incidents (workflow XDR)**](docs/03_DETECTION_AND_RESPONSE.md) : Playbook SOC, règles de corrélation XML personnalisées, Threat Intelligence et SOAR.
4. [**Résolution des incidents (troubleshooting)**](docs/04_TROUBLESHOOTING.md) : Analyse technique et résolution des problématiques complexes de routage Cloud et de conteneurisation rencontrées lors du "Build".

---

## Structure du dépôt

```text
clouds-siem-project/
 ├── architecture/     # Schémas d'architecture (phases 1 à 3)
 ├── docker/           # Fichiers Docker Compose et configurations NGINX
 ├── docs/             # Documentation complète du projet (.md)
 ├── purple-team/      # Scripts Python d'attaque (bypass CSRF & brute-force)
 ├── screenshots/      # Preuves visuelles (détections, logs, interface GCP)
 ├── terraform/        # Code de provisionnement de l'infrastructure (GCP)
 ├── wazuh-config/     # Règles de corrélation, décodeurs et dashboards exportés
 └── README.md         # Ce fichier
```

## Bilan et perspectives (Roadmap)

Ce projet a permis de valider la faisabilité technique d'un SOC complet et open-source, en couvrant l'ensemble de la chaîne de valeur : de l'ingénierie réseau Cloud (VPC, routage) jusqu'à la conteneurisation du SIEM et l'automatisation de la réponse aux incidents (SOAR). 

**Évolutions possibles :**
* **Orchestration avancée :** Migration du cluster Docker Compose vers un environnement Kubernetes (GKE) pour une gestion de la charge et une résilience de niveau production.
* **Threat Intelligence centralisée :** Déploiement d'une instance MISP (Malware Information Sharing Platform) pour enrichir la détection de Wazuh avec des sources de renseignement locales et communautaires.
* **Breach & Attack Simulation (BAS) :** Automatisation du déploiement des vecteurs d'attaques (Purple Teaming) via des playbooks Ansible pour valider l'ingénierie de détection en continu.
* **Élargissement de l'ingénierie de détection :** Le jeu de règles actuel est un démonstrateur ciblé visant à valider la viabilité de l'architecture et la réponse automatisée. L'évolution logique serait d'enrichir cette couverture de détection en s'appuyant par exemple sur le framework MITRE ATT&CK pour anticiper des menaces plus complexes.