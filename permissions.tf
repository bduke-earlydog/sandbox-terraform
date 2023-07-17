locals {
  permissions_cloudbuild = [
    "cloudbuild.builds.viewer",
    "cloudbuild.builds.approver",
    "cloudbuild.builds.editor"
  ]
  permissions_os_login = [
    "iam.serviceAccountUser",
    "compute.viewer",
    "iap.tunnelResourceAccessor",
    "compute.osLogin",
    "compute.osAdminLogin"
  ]
  permissions_admin = [
    "datamigration.admin",
    "storage.admin"
  ]
}

module "ops_team_permissions" {
  source  = "./group_permissions"
  project =      "sandbox-bradleyproject-8063"
  group   = "somegroup@lessbits.com"
  roles = [concat(
    local.permissions_admin,
    local.permissions_cloudbuild,
    local.permissions_os_login
  )]
}

module "other_team_permissions" {
  source  = "./group_permissions"
  project = "sandbox-bradleyproject-8063"
  group   = "somegroup2@lessbits.com"
  roles   = ["datamigration.admin", "storage.admin"]
}

module "application_env_permissions" {
  source                = "./group_permissions_conditional"
  project               = "sandbox-bradleyproject-8063"
  group                 = "thatgroup@lessbits.com"
  roles                 = ["roles/secretmanager.viewer", "roles/secretmanager.admin"]
  condition_title       = "env_variables"
  condition_description = "Allow access to secrets used as application env variables."
  condition_expression  = <<CONDITION_EXPRESSION
    resource.name.startsWith("projects/${local.project.number}/secrets/env_") ||
    (resource.type != "secretmanager.googleapis.com/Secret" && resource.type != "secretmanager.googleapis.com/SecretVersion")
  CONDITION_EXPRESSION
}
