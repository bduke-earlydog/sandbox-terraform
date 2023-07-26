locals {
  secrets = ["DB_DATABASE", "DB_HOST", "DB_PASSWORD", "DB_USERNAME"]
}
# Create a cloud build trigger to generate tagged container images for database migration and rollback.
resource "google_cloudbuild_trigger" "build_database_migration_image" {
  count = var.enabled == true ? 1 : 0
  name  = "database-migration-image-build-trigger"

  github {
    owner = var.github_owner
    name  = var.github_repo
    push {
      branch = "^${var.github_branch}$"
    }
  }

  build {
    # Copy the multi-stage build dockerfile to the workspace.
    step {
      name = "bash"
      args = ["-c", "echo -e '${file("${path.module}/dockerfile")}' > dockerfile"]
    }

    # Build the migrate container image.
    step {
      name = "gcr.io/cloud-builders/docker"
      args = ["build", "--target", "migrate", "-t", "gcr.io/${var.project_id}/${var.image_name}:migrate", "-f", "dockerfile", "."]
    }

    # Build the rollback container image.
    step {
      name = "gcr.io/cloud-builders/docker"
      args = ["build", "--target", "rollback", "-t", "gcr.io/${var.project_id}/${var.image_name}:rollback", "-f", "dockerfile", "."]
    }

    # Store the image artifacts in the google container registry.
    images = ["gcr.io/${var.project_id}/${var.image_name}:migrate", "gcr.io/${var.project_id}/${var.image_name}:rollback"]

    # Send logs to the google logging service.
    options {
      logging = "CLOUD_LOGGING_ONLY"
    }
  }
}

# Make sure the cloud run api is enabled.
resource "google_project_service" "cloudrun_api" {
  project            = var.project_id
  service            = "run.googleapis.com"
  disable_on_destroy = false
}

# Create job for starting the database migration.
resource "google_cloud_run_v2_job" "database_migration_start" {
  name     = "database-migration-start"
  project  = var.project_id
  location = "us-central1"

  template {
    template {
      containers {
        image = "gcr.io/${var.project_id}/${var.image_name}:migrate"
      }
    }
  }

  lifecycle {
    ignore_changes = [launch_stage]
  }
}

# Create job for rolling back database migration changes.
resource "google_cloud_run_v2_job" "database_migration_rollback" {
  name     = "database-migration-rollback"
  project  = var.project_id
  location = "us-central1"

  template {
    template {
      containers {
        image = "gcr.io/${var.project_id}/${var.image_name}:rollback"
        # Retrieve each secret in local.secrets from the secret manager, and make them available as an environment variables.
        dynamic "env" {
          for_each = local.secrets
          name     = each.value
          value_source {
            secret_key_ref {
              secret  = each.value
              version = "latest"
            }
          }
        }
      }
    }
  }

  lifecycle {
    ignore_changes = [launch_stage]
  }

}

