terraform {
  required_version = ">= 1.4.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "4.59.0"
    }
  }
}

provider "google" {
  project = "sandbox-bradleyproject-8063"
  region  = "us-central1"
}

module "database_migration_job" {
  source = "./database_migration_job"
  project_id = "sandbox-bradleyproject-8063"
  enabled = true
  github_owner = "bduke-earlydog"
  github_repo = "sandbox-terraform"
  github_branch = "composer"
  image_name = "laravel-migration"
}