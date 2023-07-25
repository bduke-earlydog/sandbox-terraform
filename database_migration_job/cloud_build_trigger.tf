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
      args = ["build", "--target", "migrate", "-t", "${var.image_name}:migrate", "-f", "dockerfile", "."]
    }

    # Build the rollback container image.
    step {
      name = "gcr.io/cloud-builders/docker"
      args = ["build", "--target", "rollback", "-t", "${var.image_name}:rollback", "-f", "dockerfile", "."]
    }

    # Store the image artifacts in the google cloud registry.
    images = ["gcr.io/${var.project_id}/${var.image_name}:migrate", "gcr.io/${var.project_id}/${var.image_name}:rollback"]

    # Send logs to the google logging service.
    options {
      logging = "CLOUD_LOGGING_ONLY"
    }
  }
}