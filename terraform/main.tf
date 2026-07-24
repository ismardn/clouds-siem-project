# ==============================================================================
# INFRASTRUCTURE AS CODE - PROJET CLOUDS (SIEM / XDR)
# ==============================================================================

terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 4.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
  zone    = var.zone
}

# ------------------------------------------------------------------------------
# 1. VARIABLES GLOBALES
# ------------------------------------------------------------------------------
variable "project_id" {
  description = "L'ID du projet Google Cloud"
  type        = string
  default     = "<VOTRE_ID_PROJET_GCP>"
}

variable "region" {
  default = "europe-west9" # Paris
}

variable "zone" {
  default = "europe-west9-a"
}

variable "ssh_pub_key" {
  description = "Clé publique SSH pour l'accès aux instances"
  type        = string
  default     = "<VOTRE_CLE_PUBLIQUE_SSH>"
}

variable "admin_ip" {
  description = "Adresse IP publique de l'administrateur autorisée à accéder au pare-feu (ex: X.X.X.X/32)"
  type        = string
}

# ------------------------------------------------------------------------------
# 2. FINOPS : GESTION DES COÛTS (ARRÊT AUTOMATIQUE)
# ------------------------------------------------------------------------------
resource "google_compute_resource_policy" "stop_instances_at_midnight" {
  name   = "stop-instances-at-midnight"
  region = var.region

  instance_schedule_policy {
    time_zone = "Europe/Paris"
    vm_stop_schedule {
      schedule = "0 0 * * *" # Arrêt tous les jours à minuit
    }
  }
}

# ------------------------------------------------------------------------------
# 3. RESEAUX (VPC) & SOUS-RESEAUX
# ------------------------------------------------------------------------------
resource "google_compute_network" "vpc_wan" { 
  name                            = "vpc-wan"
  auto_create_subnetworks         = false 
  delete_default_routes_on_create = true
}

resource "google_compute_network" "vpc_lan" { 
  name                            = "vpc-lan"
  auto_create_subnetworks         = false 
  delete_default_routes_on_create = true
}

resource "google_compute_network" "vpc_dmz" {
  name                            = "vpc-dmz"
  auto_create_subnetworks         = false 
  delete_default_routes_on_create = true
}

resource "google_compute_network" "vpc_soc" { 
  name                            = "vpc-soc"
  auto_create_subnetworks         = false 
  delete_default_routes_on_create = true
}

resource "google_compute_subnetwork" "sub_wan" { 
  name          = "sub-wan"
  ip_cidr_range = "10.0.0.0/24"
  region        = var.region
  network       = google_compute_network.vpc_wan.id 
}
resource "google_compute_subnetwork" "sub_lan" { 
  name          = "sub-lan"
  ip_cidr_range = "10.0.1.0/24"
  region        = var.region
  network       = google_compute_network.vpc_lan.id 
}
resource "google_compute_subnetwork" "sub_dmz" { 
  name          = "sub-dmz"
  ip_cidr_range = "10.0.2.0/24"
  region        = var.region
  network       = google_compute_network.vpc_dmz.id 
}
resource "google_compute_subnetwork" "sub_soc" { 
  name          = "sub-soc"
  ip_cidr_range = "10.0.3.0/24"
  region        = var.region
  network       = google_compute_network.vpc_soc.id 
}

# ------------------------------------------------------------------------------
# 4. ROUTAGE ET IP PUBLIQUE
# ------------------------------------------------------------------------------
resource "google_compute_address" "opnsense_public_ip" {
  name   = "fw-wan-interface-public-ip"
  region = var.region
}

resource "google_compute_route" "route_lan_to_opnsense" { 
  name        = "route-lan-to-opnsense"
  dest_range  = "0.0.0.0/0"
  network     = google_compute_network.vpc_lan.id
  next_hop_ip = "10.0.1.2"
  priority    = 1000 
  depends_on  = [google_compute_subnetwork.sub_lan]
}

resource "google_compute_route" "route_dmz_to_opnsense" { 
  name        = "route-dmz-to-opnsense"
  dest_range  = "0.0.0.0/0"
  network     = google_compute_network.vpc_dmz.id
  next_hop_ip = "10.0.2.2"
  priority    = 1000 
  depends_on  = [google_compute_subnetwork.sub_dmz]
}

resource "google_compute_route" "route_soc_to_opnsense" { 
  name        = "route-soc-to-opnsense"
  dest_range  = "0.0.0.0/0"
  network     = google_compute_network.vpc_soc.id
  next_hop_ip = "10.0.3.2"
  priority    = 1000 
  depends_on  = [google_compute_subnetwork.sub_soc]
}

# ------------------------------------------------------------------------------
# 5. REGLES DE PARE-FEU CLOUD (Zero-Trust interne)
# ------------------------------------------------------------------------------
resource "google_compute_firewall" "allow_internal_lan" {
  name          = "vpc-lan-allow-internal"
  network       = google_compute_network.vpc_lan.id
  direction     = "INGRESS"
  source_ranges = ["10.0.0.0/16"]

  allow {
    protocol = "all"
  }
}

resource "google_compute_firewall" "allow_internal_dmz" {
  name          = "vpc-dmz-allow-internal"
  network       = google_compute_network.vpc_dmz.id
  direction     = "INGRESS"
  source_ranges = ["0.0.0.0/0"]

  allow {
    protocol = "all"
  }
}

resource "google_compute_firewall" "allow_internal_soc" {
  name          = "vpc-soc-allow-internal"
  network       = google_compute_network.vpc_soc.id
  direction     = "INGRESS"
  source_ranges = ["10.0.0.0/16"]

  allow {
    protocol = "all"
  }
}

resource "google_compute_firewall" "allow_external_wan" {
  name          = "allow-external-wan"
  network       = google_compute_network.vpc_wan.id
  direction     = "INGRESS"
  source_ranges = [var.admin_ip]
  allow { 
    protocol = "tcp"
    ports    = ["80", "443"] 
  }
  allow { 
    protocol = "udp"
    ports    = ["51820"] 
  }
}

# ------------------------------------------------------------------------------
# 6. GESTION DE L'IMAGE OPNsense
# ------------------------------------------------------------------------------

# A. Création d'un Bucket de stockage temporaire
resource "google_storage_bucket" "opnsense_bucket" {
  name                        = "${var.project_id}-opnsense-bucket"
  location                    = var.region
  force_destroy               = true 
  uniform_bucket_level_access = true
}

# B. Upload du fichier opnsense.tar.gz local vers le Bucket
resource "google_storage_bucket_object" "opnsense_archive" {
  name   = "opnsense.tar.gz"
  source = "opnsense.tar.gz" # Terraform cherchera ce fichier dans votre dossier Windows
  bucket = google_storage_bucket.opnsense_bucket.name
}

# C. Création de l'image système Compute Engine à partir du Bucket
resource "google_compute_image" "opnsense_image" {
  name = "opnsense-custom-image"
  
  raw_disk {
    source = google_storage_bucket_object.opnsense_archive.media_link
  }

  guest_os_features {
    type = "VIRTIO_SCSI_MULTIQUEUE" # Nécessaire pour FreeBSD/OPNsense
  }
}

# ------------------------------------------------------------------------------
# 7. INSTANCES DE CALCUL (MACHINES VIRTUELLES)
# ------------------------------------------------------------------------------

# --- A. Le routeur / Pare-feu principal (OPNsense) ---
resource "google_compute_instance" "opnsense_vm" {
  name              = "opnsense-vm"
  machine_type      = "e2-highcpu-4"
  zone              = var.zone
  can_ip_forward    = true
  resource_policies = [google_compute_resource_policy.stop_instances_at_midnight.id]

  boot_disk {
    initialize_params { 
      image = google_compute_image.opnsense_image.self_link
      size  = 50
      type  = "pd-balanced"
    }
  }

  metadata = {
    serial-port-enable = "TRUE"
  }

  network_interface { # WAN
    network    = google_compute_network.vpc_wan.id
    subnetwork = google_compute_subnetwork.sub_wan.id
    network_ip = "10.0.0.2"
    access_config { 
      nat_ip = google_compute_address.opnsense_public_ip.address 
    }
  }
  network_interface { # LAN
    network    = google_compute_network.vpc_lan.id
    subnetwork = google_compute_subnetwork.sub_lan.id
    network_ip = "10.0.1.2"
  }
  network_interface { # DMZ
    network    = google_compute_network.vpc_dmz.id
    subnetwork = google_compute_subnetwork.sub_dmz.id
    network_ip = "10.0.2.2"
  }
  network_interface { # SOC
    network    = google_compute_network.vpc_soc.id
    subnetwork = google_compute_subnetwork.sub_soc.id
    network_ip = "10.0.3.2"
  }
}

# --- B. Le cœur du SIEM/XDR (Docker Host) ---
resource "google_compute_instance" "wazuh_docker_host" {
  name              = "wazuh-docker-host"
  machine_type      = "e2-standard-4"
  zone              = var.zone
  resource_policies = [google_compute_resource_policy.stop_instances_at_midnight.id]

  boot_disk {
    initialize_params { 
      image = "projects/ubuntu-os-cloud/global/images/family/ubuntu-2404-lts"
      size  = 100
      type  = "pd-balanced"
    }
  }
  
  metadata = { 
    ssh-keys = "ubuntu:${var.ssh_pub_key}" 
  }
  
  network_interface {
    network    = google_compute_network.vpc_soc.id
    subnetwork = google_compute_subnetwork.sub_soc.id
    network_ip = "10.0.3.20"
  }
}

# --- C. Les cibles de supervision (Client/Serveur) ---
resource "google_compute_instance" "web_server" {
  name              = "web-server"
  machine_type      = "e2-small"
  zone              = var.zone
  resource_policies = [google_compute_resource_policy.stop_instances_at_midnight.id]

  boot_disk {
    initialize_params { 
      image = "projects/ubuntu-os-cloud/global/images/family/ubuntu-2404-lts"
      size  = 20 
      type  = "pd-standard"
    }
  }
  
  metadata = { 
    ssh-keys = "ubuntu:${var.ssh_pub_key}" 
  }
  
  network_interface {
    network    = google_compute_network.vpc_dmz.id
    subnetwork = google_compute_subnetwork.sub_dmz.id
    network_ip = "10.0.2.10"
  }
}

resource "google_compute_instance" "windows_server" {
  name              = "windows-server"
  machine_type      = "e2-medium"
  zone              = var.zone
  resource_policies = [google_compute_resource_policy.stop_instances_at_midnight.id]

  boot_disk {
    initialize_params { 
      image = "projects/windows-cloud/global/images/family/windows-2022"
      size  = 50 
      type  = "pd-balanced"
    }
  }
  
  network_interface {
    network    = google_compute_network.vpc_lan.id
    subnetwork = google_compute_subnetwork.sub_lan.id
    network_ip = "10.0.1.10"
  }
}