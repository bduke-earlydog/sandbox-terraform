variable "project_id" {
  type        = string
  description = "Project ID to create resources in."
}

variable "region" {
  type        = string
  description = "Region to create resources in."
}

variable "subnets" {
  type        = map(string)
  description = "Map of subnets. Keys should be subnet names, and values should be the ip range in cidr format."
}

variable "nat_external_ip_count" {
  type        = number
  description = "Number of external IP addresses to assign to the NAT service."
}

