output "vpc_id" {
  description = "The ID of the main VPC."
  value       = google_compute_network.vpc.id
}

output "subnet_ids" {
  description = "A map of subnet ids. Keys are the subnet names, and values are the subnet IDs."
  value       = { for subnet in google_compute_subnetwork.subnet : subnet.name => subnet.id }
}

output "nat_ips" {
  description = "External IP addresses assigned to the NAT service."
  value = google_compute_address.nat.*.address
}