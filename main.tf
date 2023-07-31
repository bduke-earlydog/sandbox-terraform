locals {
  project_id = "sandbox-bradleyproject-8063"
  project_num = 663094282202
  location   = "us-central1"
}

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
  project = local.project_id
  region  = local.location
}

module "database_migration_job" {
  source        = "./database_migration_job"
  count         = 1
  project_id    = local.project_id
  project_num   = local.project_num
  location      = local.location
  github_owner  = "bduke-earlydog"
  github_repo   = "sandbox-terraform"
  github_branch = "laravel"
  image_name    = "laravel-migration"
}