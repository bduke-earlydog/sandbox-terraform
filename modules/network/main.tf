resource "google_project_service" "compute_api" {
  project    = var.project_id
  service    = "compute.googleapis.com"
}

resource "google_project_service" "service_networking_api" {
  service = "servicenetworking.googleapis.com"
}

resource "google_compute_network" "vpc" {
  name                    = "${var.project_id}-vpc"
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "subnet" {
  for_each      = var.subnets
  region        = var.region
  network       = google_compute_network.vpc.id
  name          = each.key
  ip_cidr_range = each.value
}

# # Set firewall rules
# resource "google_compute_firewall" "ssh_iap" {
#   project       = var.project_id_id
#   name          = "allow-ssh-iap"
#   description   = "Allow SSH connections from the IAP networks."
#   network       = google_compute_network.vpc.name
#   source_ranges = ["35.235.240.0/20"]
#   allow {
#     protocol = "tcp"
#     ports    = ["22"]
#   }
# }

resource "google_compute_global_address" "service_peering" {
  network       = google_compute_network.vpc.id
  name          = "service-peering"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 16
}

resource "google_service_networking_connection" "service_peering" {
  network                 = google_compute_network.vpc.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.service_peering.name]
}

resource "google_compute_router" "router" {
  name    = "router-1"
  region  = var.region
  network = google_compute_network.vpc.id
}

resource "google_compute_address" "nat" {
  count        = var.nat_external_ip_count
  name         = "nat-external-ip-${count.index}"
  region       = var.region
  address_type = "EXTERNAL"
}

resource "google_compute_router_nat" "nat" {
  name                                = "${google_compute_network.vpc.name}-nat"
  router                              = google_compute_router.router.name
  nat_ip_allocate_option              = "MANUAL_ONLY"
  nat_ips                             = google_compute_address.nat.*.self_link
  source_subnetwork_ip_ranges_to_nat  = "ALL_SUBNETWORKS_ALL_IP_RANGES"
  min_ports_per_vm                    = 2048
  enable_endpoint_independent_mapping = false
  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }
}