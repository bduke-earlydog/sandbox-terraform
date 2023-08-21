output "external_ip" {
  description = "The static external IP address for the instance."
  value       = google_compute_address.static_external.address
}