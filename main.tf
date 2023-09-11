locals {
  org_id       = "26105214336"
  project_id   = "sandbox-bradleyproject-8063"
  project_name = "Bradley Project"
  region       = "us-central1"
}

terraform {
  required_version = ">= 1.5.6"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "4.80.0"
    }
  }
}

provider "google" {
  project = local.project_id
  region  = local.region
}

# Using the google_project resource will create or update a GCP project.
# I don't have sufficient permissions for this in the org.
# Instead, I am using a data source for my existing sandbox project below.
# resource "google_project" "project" {
#   org_id     = local.org_id
#   project_id = local.project_id
#   name       = local.project_name
# }

data "google_project" "project" {
  project_id = local.project_id
}

module "network" {
  source     = "./modules/network"
  project_id = local.project_id
  region     = local.region
  subnets = {
    "compute" = "10.0.0.0/24"
    "db"      = "10.0.1.0/24"
  }
  nat_external_ip_count = 1
}

# Compute instance template
# Instace group manager
# Load balancer
# Health check
# Autoscaler
# APIs

locals {
  some_script = templatefile("${path.root}/files/test/some_script_i_want.sh.tpl", {
    PROJECT_ID = "${local.project_id}"
  })
  startup_script = templatefile("${path.root}/files/test/startup_script.sh.tpl", {
    REGION      = "${local.region}"
    PROJECT     = "${local.project_id}"
    SOME_SCRIPT = "${local.some_script}"
  })
}

# TODO: add option to assign static external IP to instances.
# https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_instance_template.html#nested_access_config
module "test_mig" {
  source       = "./modules/mig"
  project_id   = local.project_id
  region       = local.region
  mig_zones    = ["${local.region}-a", "${local.region}-b"]
  name         = "test"
  tags         = ["test"]
  machine_type = "e2-micro"
  disks = [
    {
      "image" = "ubuntu-os-cloud/ubuntu-2004-lts"
      "boot"  = true
      "size"  = 10
    }
  ]
  subnet                   = module.network.subnet_ids.compute
  service_account_roles    = ["roles/compute.instanceAdmin.v1", "roles/compute.osAdminLogin", "roles/cloudsql.client", "roles/secretmanager.secretAccessor", "roles/iam.serviceAccountUser"]
  service_account_scopes   = ["cloud-platform"]
  service_account_users    = ["bradley@lessbits.com"]
  service_account_groups   = []
  update_type              = "OPPORTUNISTIC"
  update_action            = "REPLACE"
  update_surge_fixed       = 2
  update_unavailable_fixed = 0
  update_on_repair         = "YES"
  scale_min                = 1
  scale_max                = 1
  scale_cooldown           = 60
  scale_cpu_target         = 0.7
  startup_script           = local.startup_script
}