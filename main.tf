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

# resource "google_compute_instance" "test" {
#   project = local.project_id
#   zone = "${local.location}-a"
#   machine_type = local.machine_type
#   name = "test-machine"
#   boot_disk {
#     initialize_params {
#       image = "ubuntu-os-cloud/ubuntu-2004-lts"
#     }
#   }
#   network_interface {
#     subnetwork = google_compute_subnetwork.subnet.id
#   }
#   metadata = {
#     user-data = file("cloud-init.yaml")
#   }
# }

locals {
  database_map = {
    "primary"  = 3306
    "replica" = 3307
  }

  # Convert the Terraform database to ports map into an associative Bash array, so that it can be iterated on in the startup script.
  database_map_string = join(", ", [for name, port in local.database_map : "[\"${name}\"]=\"${port}\""])

  enable_maintenance_mode_script = templatefile("files/enable_maintenance_mode.sh.tpl", {
    PROJECT = "${local.project_id}"
  })
  disable_maintenance_mode_script = templatefile("files/disable_maintenance_mode.sh.tpl", {
    PROJECT = "${local.project_id}"
  })
  startup_script = templatefile("files/startup_script.sh.tpl", {
    PROJECT                         = "${local.project_id}"
    DISABLE_MAINTENANCE_MODE_SCRIPT = "${local.disable_maintenance_mode_script}"
    ENABLE_MAINTENANCE_MODE_SCRIPT  = "${local.enable_maintenance_mode_script}"
    DATABASE_MAP_STRING             = "${local.database_map_string}"
  })
}

resource "google_compute_instance" "test" {
  project = local.project_id
  zone = "${local.location}-a"
  machine_type = local.machine_type
  name = "test-machine"
  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2004-lts"
    }
  }
  network_interface {
    subnetwork = google_compute_subnetwork.subnet.id
  }
  metadata_startup_script = local.startup_script
}