variable "project_id" {
  type        = string
  description = "ID of the project."
}

variable "region" {
  type        = string
  description = "Region to create resources in."
}

variable "service_account_roles" {
  type        = list(string)
  description = "GCP permission roles to assign the new service account."
}

variable "network" {
  type        = string
  description = "Network to grant firewall access in."
}

variable "allow_ssh" {
  type        = list(string)
  description = "CIDR format IP ranges to allow SSH access."
}

variable "allow_https" {
  type        = list(string)
  description = "CIDR format IP ranges to allow HTTPS access."
}

variable "instance_image" {
  type        = string
  description = "OS image to use when creating the instance."
}

variable "machine_type" {
  type        = string
  description = "Machine type of the new instance."
}

variable "instance_disk_size" {
  type        = number
  description = "GB of disk space to allocate."
}

variable "instance_subnet" {
  type        = string
  description = "Name of the subnet to attach the instance to."
}

variable "database_primary_name" {
  type        = string
  description = "Name of the main database where users will be created."
}

variable "database_map" {
  type        = map(number)
  description = "A map of database names to ports to use with Cloud SQL Proxy and PMM."
}

variable "mig_zones" {
  type        = list(string)
  description = "A list of two zones to use for the mig."
}