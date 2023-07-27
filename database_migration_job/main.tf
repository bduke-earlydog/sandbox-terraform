locals {
  secrets = ["DB_DATABASE", "DB_HOST", "DB_PASSWORD", "DB_USERNAME"]
}

data "google_project" "project" {
  project_id = var.project_id
}

# Assign Secret Manager Secret Accessor role for accessing the github ssh key.
resource "google_project_iam_member" "secretacessor_role" {
  project = var.project_id
  role    = "roles/secretmanager.secretAccessor"
  member  = "serviceAccount:${data.google_project.project.number}-compute@developer.gserviceaccount.com"
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
    # Add the dockerfile and secrets download script to the cloud build workspace.
    step {
      name = "bash"
      args = ["-c", "echo -e '${file("${path.module}/dockerfile")}' > dockerfile && echo -e '${file("${path.module}/download_secrets.sh")}' > download_secrets.sh"]
    }

    # Build the migrate container image.
    step {
      name = "gcr.io/cloud-builders/docker"
      args = ["build", "--target", "base", "-t", "gcr.io/${var.project_id}/${var.image_name}:base", "-f", "dockerfile", "."]
    }

    # Store the image artifacts in the google container registry.
    images = ["gcr.io/${var.project_id}/${var.image_name}:base"]

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
        image = "gcr.io/${var.project_id}/${var.image_name}:base"
      }
    }
  }

  lifecycle {
    ignore_changes = [launch_stage]
  }
}


