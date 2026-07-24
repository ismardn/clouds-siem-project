# Déploiement de l'infrastructure (IaC)

Ce dossier contient le code Terraform utilisé pour provisionner l'infrastructure sous-jacente du projet CLOUDS sur Google Cloud Platform (GCP).

## Périmètre

Ce code déploie exclusivement les ressources matérielles et réseaux (IaaS) :
- **Segmentation réseau :** Création de 4 VPC isolés (WAN, LAN, DMZ, SOC).
- **Routage manuel :** Forçage de tout le trafic interne vers l'appliance OPNsense.
- **Pare-feu cloud :** Règles *zero-trust* par défaut avec ouvertures spécifiques (WireGuard, HTTP/S) limitées à l'IP de l'administrateur.
- **Compute :** 4 machines virtuelles (OPNsense, Docker Host, cibles Windows/Ubuntu).
- **FinOps :** Stratégie d'arrêt automatique des serveurs de test à minuit pour optimiser les coûts de laboratoire.

> **Note importante :** Ce code provisionne l'infrastructure vierge. La configuration du routeur OPNsense et le déploiement applicatif du SOC (Wazuh) sont gérés respectivement via l'interface web de l'appliance et via Docker Compose (voir le dossier `docker/`).

## Préparation de l'image OPNsense (prérequis)

Google Cloud ne fournissant pas d'image native pour OPNsense, vous devez préparer une image système personnalisée **avant** d'exécuter Terraform.

1. Rendez-vous sur [le site officiel OPNsense](https://pkg.opnsense.org/releases/) pour télécharger la dernière version **nano** (architecture amd64).
2. Préparez l'archive au format strict exigé par Google Cloud en exécutant ces commandes :

    ```bash
    # Décompression de l'image bz2
    bunzip2 OPNsense-XX.X-nano-amd64.img.bz2
    
    # Renommage obligatoire du fichier brut
    mv OPNsense-XX.X-nano-amd64.img disk.raw
    
    # Création de l'archive tarball optimisée
    tar -Sczf opnsense.tar.gz disk.raw
    ```

3. Placez le fichier `opnsense.tar.gz` généré directement à la racine de ce dossier Terraform (au même niveau que le fichier `main.tf`). Terraform se chargera automatiquement de l'uploader et de l'installer.

## Configuration et utilisation

1. Créez un fichier nommé `terraform.tfvars` à la racine de ce dossier pour définir vos variables locales. Ce fichier ne doit pas être versionné (ajoutez-le à votre `.gitignore`).

    **Exemple de contenu pour `terraform.tfvars` :**
    ```hcl
    project_id  = "votre-id-projet-gcp"
    admin_ip    = "X.X.X.X/32" # Votre IP publique pour l'accès WAN
    ssh_pub_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC..." # Clé publique pour l'accès aux VM
    ```

2. Initialisez l'environnement Terraform :
    ```bash
    terraform init
    ```
3. Vérifiez le plan de déploiement :
    ```bash
    terraform plan
    ```
4. Déployez l'infrastructure :
    ```bash
    terraform apply
    ```