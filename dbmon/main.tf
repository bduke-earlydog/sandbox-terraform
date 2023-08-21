locals {
  instance_name = "dbmon"
  instance_tags = ["${local.instance_name}"]

  # Convert the Terraform database to ports map into an associative Bash array, so that it can be iterated on in the startup script.
  database_map_string = join(" ", [for name, port in var.database_map : "[${name}]=\"${port}\""])

  # Store the startup script as a variable after injecting necessary variables into the template.
  startup_script = templatefile("${path.module}/files/startup_script.sh.tpl", {
    REGION                           = "${var.region}"
    PROJECT                          = "${var.project_id}"
    DATABASE_MAP_STRING              = "${local.database_map_string}"
    METADATA_KEY_PERFORM_DISK_FORMAT = "${google_compute_project_metadata_item.perform_pmm_disk_format.key}"
    PMM_ADMIN_PASSWORD               = "${random_password.pmm_admin_user.result}"
    PMM_SQL_PASSWORD                 = "${random_password.pmm_sql_user.result}"
  })
}

########## Service Accounts and APIs

# Enable the Cloud SQL Admin API.
resource "google_project_service" "cloud-sql-admin-api" {
  service = "sqladmin.googleapis.com"
}

# Create service account for the compute instance.
resource "google_service_account" "dbmon_service_account" {
  project     = var.project_id
  account_id  = "dbmon-service-account"
  description = "Service account for dbmon instances."
}

# Assign service account permissions.
resource "google_project_iam_member" "dbmon_service_account_permission" {
  for_each = toset(var.service_account_roles)
  project  = var.project_id
  role     = each.value
  member   = "serviceAccount:${google_service_account.dbmon_service_account.email}"
}

########## PMM MySQL user account

# Generate a password for the PMM MySQL user.
resource "random_password" "pmm_sql_user" {
  length  = 24
  special = false
}

# Create the Percona Monitoring and Management user in the MySQL database.
resource "google_sql_user" "pmm_user" {
  project  = var.project_id
  instance = var.database_primary_name
  name     = "pmm"
  password = random_password.pmm_sql_user.result
}

# Create a secret to store the PMM SQL user password.
resource "google_secret_manager_secret" "pmm_sql_password" {
  secret_id = "pmm_sql_password"
  replication {
    automatic = true
  }
}

# Store the PMM SQL user password in secrets manager.
resource "google_secret_manager_secret_version" "pmm_sql_password" {
  secret      = google_secret_manager_secret.pmm_sql_password.id
  secret_data = random_password.pmm_sql_user.result
}

########## PMM Software Admin Account

# Generate a password for the PMM admin account.
resource "random_password" "pmm_admin_user" {
  length  = 24
  special = false
}

# Create a secret to store the PMM admin account password.
resource "google_secret_manager_secret" "pmm_admin_password" {
  secret_id = "pmm_admin_password"
  replication {
    automatic = true
  }
}

# Store the PMM admin account password in secrets manager.
resource "google_secret_manager_secret_version" "pmm_admin_password" {
  secret      = google_secret_manager_secret.pmm_admin_password.id
  secret_data = random_password.pmm_admin_user.result
}

########## Network and Firewall

# Allow SSH.
resource "google_compute_firewall" "allow_ssh" {
  project       = var.project_id
  name          = "allow-ssh"
  network       = var.network
  source_ranges = var.allow_ssh
  target_tags   = local.instance_tags
  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
}

# Allow HTTPS.
resource "google_compute_firewall" "allow_https" {
  project       = var.project_id
  name          = "allow-https"
  network       = var.network
  source_ranges = var.allow_https
  target_tags   = local.instance_tags
  allow {
    protocol = "tcp"
    ports    = ["443"]
  }
}

# Create static external IP.
resource "google_compute_address" "static_external" {
  project      = var.project_id
  region       = var.region
  name         = "${local.instance_name}-static-external-ip"
  address_type = "EXTERNAL"
}

########## Persistent Disk

# Create a persistent disk to store PMM data.
resource "google_compute_region_disk" "pmm_disk" {
  project       = var.project_id
  region        = var.region
  replica_zones = var.mig_zones
  name          = "pmm-disk"
  # Minimum size for a regional standard disk is 200 GB.
  # https://cloud.google.com/compute/docs/disks#introduction
  type = "pd-standard"
  size = 200
  lifecycle {
    prevent_destroy = false
  }
}

# Create a project wide metadata item for storing whether the disk has been formatted already.
# This defaults to true so the format is run the first time. When the startup script runs the disk format, it will change this to false.
resource "google_compute_project_metadata_item" "perform_pmm_disk_format" {
  project = var.project_id
  key     = "perform_pmm_disk_format"
  value   = "true"
  lifecycle {
    # Ignore changes to the value, so Terraform doesn't set this to true every time it is run.
    ignore_changes = [value]
  }
}

########## Compute Instance and Deployment

# Create instance template to use with the MIG.
resource "google_compute_instance_template" "dbmon_instance_template" {
  name_prefix  = "instance-template-"
  project      = var.project_id
  machine_type = var.machine_type
  tags         = local.instance_tags

  disk {
    source_image = var.instance_image
    boot         = true
    disk_size_gb = var.instance_disk_size
  }

  disk {
    source      = google_compute_region_disk.pmm_disk.self_link
    boot        = false
    auto_delete = false
  }

  network_interface {
    subnetwork = var.instance_subnet
    access_config {
      nat_ip = google_compute_address.static_external.address
    }
  }

  lifecycle {
    create_before_destroy = true
  }

  service_account {
    email  = google_service_account.dbmon_service_account.email
    scopes = ["cloud-platform"]
  }

  metadata_startup_script = local.startup_script
}

# Create the machine instance group manager.
resource "google_compute_region_instance_group_manager" "dbmon_instance_manager" {
  project                   = var.project_id
  region                    = var.region
  name                      = "${local.instance_name}-mig"
  base_instance_name        = local.instance_name
  distribution_policy_zones = var.mig_zones

  version {
    instance_template = google_compute_instance_template.dbmon_instance_template.self_link_unique
  }

  update_policy {
    type           = "OPPORTUNISTIC"
    minimal_action = "REPLACE"
    # There should only ever be a single instance up at a time, since the persistent data disk can only mount to one VM at a time.
    max_surge_fixed       = 0
    max_unavailable_fixed = length(var.mig_zones)
  }

  target_size = 1
}