terraform {
  required_version = ">= 1.5.3"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "4.75.0"
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
  github_branch = "laravel"
  image_name = "laravel-migration"
}