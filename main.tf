locals {
  project_id   = "sandbox-bradleyproject-8063"
  project_num  = 663094282202
  location     = "us-central1"
  machine_type = "n1-standard-1"
}

terraform {
  required_version = ">= 1.5.3"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "4.77.0"
    }
  }
}

provider "google" {
  project = local.project_id
  region  = local.location
}

resource "google_compute_network" "vpc" {
  name                    = "${local.project_id}-vpc"
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "subnet" {
  name          = "main-subnet"
  ip_cidr_range = "10.4.0.0/20"
  region        = local.location
  network       = google_compute_network.vpc.id
}

# Set firewall rules
resource "google_compute_firewall" "ssh_iap" {
  project       = local.project_id
  name          = "allow-ssh-iap"
  description   = "Allow SSH connections from the IAP networks."
  network       = google_compute_network.vpc.name
  source_ranges = ["35.235.240.0/20"]
  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
}

resource "google_compute_global_address" "private_ip_address" {
  name          = "private-ip-address"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 16
  network       = google_compute_network.vpc.id
}

resource "google_service_networking_connection" "default" {
  network                 = google_compute_network.vpc.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_ip_address.name]
}

resource "google_compute_router" "default" {
  name    = "router"
  region  = local.location
  network = google_compute_network.vpc.id
}

resource "google_compute_router_nat" "default" {
  name                               = "nat"
  region                             = local.location
  router                             = google_compute_router.default.name
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"
}

resource "google_sql_database_instance" "primary" {
  project             = local.project_id
  region              = local.location
  name                = "primary-db"
  database_version    = "MYSQL_8_0_32"
  deletion_protection = false
  settings {
    tier                        = "db-f1-micro"
    deletion_protection_enabled = false
    ip_configuration {
      ipv4_enabled    = true
      private_network = google_compute_network.vpc.id
    }
    backup_configuration {
      enabled            = true
      binary_log_enabled = true
    }
    database_flags {
      name  = "innodb_monitor_enable"
      value = "all"
    }
  }
  depends_on = [google_service_networking_connection.default]
}

resource "google_sql_database_instance" "replica" {
  project              = local.project_id
  region               = local.location
  name                 = "replica-db"
  database_version     = "MYSQL_8_0_32"
  master_instance_name = google_sql_database_instance.primary.id
  deletion_protection  = false
  settings {
    tier                        = "db-f1-micro"
    deletion_protection_enabled = false
    ip_configuration {
      ipv4_enabled    = true
      private_network = google_compute_network.vpc.id
    }
  }
}

module "dbmon" {
  source                = "./dbmon"
  project_id            = local.project_id
  region                = local.location
  service_account_roles = ["roles/compute.instanceAdmin.v1", "roles/compute.osAdminLogin", "roles/cloudsql.client", "roles/secretmanager.secretAccessor"]
  network               = google_compute_network.vpc.name
  machine_type          = local.machine_type
  instance_image        = "ubuntu-os-cloud/ubuntu-2004-lts"
  instance_subnet       = google_compute_subnetwork.subnet.name
  instance_disk_size    = 10
  mig_zones             = ["${local.location}-a", "${local.location}-b"]
  database_primary_name = google_sql_database_instance.primary.name
  allow_https = values({
    brad_home_ip = "71.221.33.170/32"
  })
  allow_ssh = values({
    brad_home_ip = "71.221.33.170/32"
  })
  database_map = {
    "${google_sql_database_instance.primary.name}" = 3306
    "${google_sql_database_instance.replica.name}" = 3307
  }
}