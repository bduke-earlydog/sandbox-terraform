output "template" {
  value       = google_compute_instance_template.template
  description = "The instance group template."
}

output "manager" {
  value       = google_compute_region_instance_group_manager.mig
  description = "The instance group manager."
}

output "autoscaler" {
  value       = google_compute_region_autoscaler.autoscaler
  description = "The instance group autoscaler."
}

output "service_account" {
  value       = google_service_account.service_account
  description = "The instance group service account."
}

output "health_check_id" {
  value       = var.health_check_id != null ? var.health_check_id : null
  description = "The health check id. Returns null if no health check was used."
}