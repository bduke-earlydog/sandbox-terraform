output "external_ip" {
  description = "The static external IP address for the instance."
  value       = module.dbmon.external_ip
}