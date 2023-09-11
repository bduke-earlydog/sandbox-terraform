resource "google_project_service" "cloudsql_api" {
  project = var.project
  service = "compute.googleapis.com"
}

resource "google_sql_database_instance" "primary" {
  project          = var.project
  region           = var.region
  name             = "${name}-primary-instance"
  database_version = var.version
  # Terraform deletion protection
  deletion_protection = true
  settings {
    # GCP deletion protection
    deletion_protection_enabled = true
    tier                        = var.primary_machine_type
    availability_type           = var.availability
    ip_configuration {
      ipv4_enabled       = var.enable_public_ip
      private_network    = var.vpc_id
      allocated_ip_range = var.subnet_range
      dynamic "authorized_networks" {
        for_each = var.authorized_networks
        content {
          name  = each.key
          value = each.value
        }
      }
    }
    backup_configuration {
      enabled            = var.enable_backups
      binary_log_enabled = var.enable_backups
      start_time         = var.backup_time
      backup_retention_settings {
        retained_backups = var.backup_retention
      }
    }
    maintenance_window {
      day          = var.maintenance_day
      hour         = var.maintenance_hour
      update_track = var.maintenance_track
    }
    dynamic "database_flags" {
      for_each = var.database_flags
      content {
        name  = each.key
        value = each.value
      }
    }
  }
}

resource "google_sql_database_instance" "replica" {
  count                = var.enable_replica == true ? 1 : 0
  project              = var.project
  region               = var.region
  name                 = "${name}-replica-instance"
  database_version     = var.version
  master_instance_name = google_sql_database_instance.primary.name
  # Terraform deletion protection
  deletion_protection = true
  settings {
    # GCP deletion protection
    deletion_protection_enabled = true
    tier                        = var.replica_machine_type
    availability_type           = var.availability
    ip_configuration {
      ipv4_enabled       = var.enable_public_ip
      private_network    = var.vpc_id
      allocated_ip_range = var.subnet_range
      dynamic "authorized_networks" {
        for_each = var.authorized_networks
        content {
          name  = each.key
          value = each.value
        }
      }
    }
  }
  replica_configuration {
    failover_target = var.enable_replica_failover
  }
}

resource "google_sql_database" "database" {
  for_each = var.databases
  project  = var.project
  name     = "${name}-${each.value}"
  instance = google_sql_database_instance.primary.id
  lifecycle {
    prevent_destroy = true
  }
}

resource "random_password" "sql_root_password" {
  length  = 24
  special = false
}

resource "google_sql_user" "root" {
  project  = var.project
  name     = "root"
  instance = google_sql_database_instance.primary.id
  host     = "%"
  password = random_password.sql_root_password.result
}

resource "google_secret_manager_secret" "cloudsql_root_password" {
  project   = var.project
  secret_id = "cloudsql_root_password"
  replication {
    automatic = true
  }
}

resource "google_secret_manager_secret_version" "cloudsql_root_password" {
  project     = var.project
  secret      = google_secret_manager_secret.cloudsql_root_password.id
  secret_data = random_password.sql_root_password.result
}