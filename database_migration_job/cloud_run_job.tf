# Enable Cloud Run API
resource "google_project_service" "cloudrun_api" {
  project            = var.project_id
  service            = "run.googleapis.com"
  disable_on_destroy = false
}

resource "google_cloud_run_v2_job" "database_migration_start" {
  name     = "database-migration-start"
  location = "us-central1"

  template {
    template {
      containers {
        image = "gcr.io/${var.project_id}/${var.image_name}:migrate"
      }
    }
  }

  lifecycle {
    ignore_changes = [
      launch_stage,
    ]
  }
}

resource "google_cloud_run_v2_job" "database_migration_rollback" {
  name     = "database-migration-rollback"
  location = "us-central1"

  template {
    template {
      containers {
        image = "gcr.io/${var.project_id}/${var.image_name}:migrate"
      }
    }
  }

  lifecycle {
    ignore_changes = [
      launch_stage,
    ]
  }
}