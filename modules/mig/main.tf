# Enable compute engine api.
# If the os_login_api is being enabled for the first time, this resource may fail to create at first.
# Allow time for the os_login_api to be enabled and propagate, and then re-run the terraform apply.
resource "google_project_service" "compute_api" {
  project    = var.project_id
  service    = "compute.googleapis.com"
  depends_on = [google_project_service.os_login_api]
}

# Enable os login api.
resource "google_project_service" "os_login_api" {
  project = var.project_id
  service = "oslogin.googleapis.com"
}

# Create service account for MIG.
resource "google_service_account" "service_account" {
  project     = var.project_id
  account_id  = "${var.name}-service-account"
  description = "Service account for the ${var.name} MIG."
}

# Assign service account permissions.
resource "google_project_iam_member" "service_account_roles" {
  for_each = toset(var.service_account_roles)
  project  = var.project_id
  role     = each.value
  member   = "serviceAccount:${google_service_account.service_account.email}"
}

# Grant users access to impersonate the service account for OS Logins.
resource "google_service_account_iam_member" "service_account_user" {
  for_each           = toset(var.service_account_users)
  service_account_id = google_service_account.service_account.name
  role               = "roles/iam.serviceAccountUser"
  member             = "user:${each.value}"
}

# Grant users access to impersonate the service account for OS Logins.
resource "google_service_account_iam_member" "service_account_group" {
  for_each           = toset(var.service_account_groups)
  service_account_id = google_service_account.service_account.name
  role               = "roles/iam.serviceAccountUser"
  member             = "group:${each.value}"
}

# Create instance template the instance group manager uses to deploy instances.
resource "google_compute_instance_template" "template" {
  name_prefix  = "${var.name}-template"
  project      = var.project_id
  machine_type = var.machine_type
  tags         = var.tags
  dynamic "disk" {
    for_each = var.disks
    content {
      source_image = try(lookup(disk.value, "image"), null)
      source       = try(lookup(disk.value, "source"), null)
      boot         = disk.value.boot
      disk_size_gb = disk.value.size
    }
  }
  network_interface {
    subnetwork = var.subnet
  }
  lifecycle {
    create_before_destroy = true
  }
  service_account {
    email  = google_service_account.service_account.email
    scopes = var.service_account_scopes
  }
  metadata_startup_script = var.startup_script
}

# Create the machine instance group manager to handle deployment of instances.
resource "google_compute_region_instance_group_manager" "mig" {
  project                   = var.project_id
  region                    = var.region
  name                      = "${var.name}-manager"
  base_instance_name        = var.name
  distribution_policy_zones = var.mig_zones
  version {
    instance_template = google_compute_instance_template.template.self_link_unique
  }
  update_policy {
    type                  = var.update_type
    minimal_action        = var.update_action
    max_surge_fixed       = var.update_surge_fixed
    max_unavailable_fixed = var.update_unavailable_fixed
  }
  instance_lifecycle_policy {
    force_update_on_repair = var.update_on_repair
  }
  dynamic "auto_healing_policies" {
    for_each = var.health_check_id != null ? [var.health_check_id] : []
    content {
      health_check      = var.health_check_id
      initial_delay_sec = var.health_check_delay
    }
  }
}

# Create an autoscaler to determine the number of instances the group manager should deploy.
resource "google_compute_region_autoscaler" "autoscaler" {
  project = var.project_id
  region  = var.region
  name    = "${var.name}-autoscaler"
  target  = google_compute_region_instance_group_manager.mig.id
  autoscaling_policy {
    min_replicas    = var.scale_min
    max_replicas    = var.scale_max
    cooldown_period = var.scale_cooldown
    cpu_utilization {
      target = var.scale_cpu_target
    }
  }
}