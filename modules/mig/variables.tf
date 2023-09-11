variable "project_id" {
  type        = string
  description = "Project ID to create resources in."
}

variable "region" {
  type        = string
  description = "Region to create resources in."
}

variable "mig_zones" {
  type        = list(string)
  description = "Two zones to use with the MIG."
}

variable "name" {
  type        = string
  description = "Name to use for resources in the MIG. May only contain lowercase letters, numbers, and dashes."
}

variable "machine_type" {
  type        = string
  description = "Machine type to use for deployed instances."
}

variable "startup_script" {
  type        = string
  description = "Startup script to use when deploying instances."
}

variable "tags" {
  type        = list(string)
  description = "Tags to assign to deployed instances."
}

variable "disks" {
  type        = list(map(string))
  description = "Disks to attach to each deployed instance. Each item in the list should be a map containing: image(string) or source(string), boot(bool), and size(number)"
}

variable "subnet" {
  type        = string
  description = "Subnet to deploy instance to."
}

variable "service_account_roles" {
  type        = list(string)
  description = "Roles to assign the service account that handles the MIG."
}

variable "service_account_scopes" {
  type        = list(string)
  description = "Service scopes to assign the service account."
}

variable "service_account_users" {
  type        = list(string)
  description = "Users that have permission to impersonate the service account. This is necessary for OS Logins."
}

variable "service_account_groups" {
  type        = list(string)
  description = "Groups that have permission to impersonate the service account. This is necessary for OS Logins."
}

variable "update_type" {
  type        = string
  description = "Update type for the MIG. Should be either PROACTIVE or OPPORTUNISTIC."
}

variable "update_action" {
  type        = string
  description = "Update action for the MIG. Should be REFRESH, RESTART, or REPLACE."
}

variable "update_surge_fixed" {
  type        = number
  description = "Max number of additional instances that can be created during the update process. Must be 0, or >= to the number of zones."
}

variable "update_unavailable_fixed" {
  type        = string
  description = "Max number of unavailable instances during the update process. Must be 0, or >= to the number of zones."
}

variable "update_on_repair" {
  type        = string
  description = "Update instances when repairing them. Should be YES or NO."
}

variable "health_check_id" {
  type        = string
  description = "ID of a health check to use for determining if an instances should be auto-healed. If left null, no auto healing policy will be created."
  default     = null
}

variable "health_check_delay" {
  type        = number
  description = "Number of seconds to delay autohealing health checks after an instance is deployed. Must be between 0 and 3600."
  default     = 300
}

variable "scale_min" {
  type        = number
  description = "Minimum number of deployed instances when autoscaling."
}

variable "scale_max" {
  type        = number
  description = "Maxmimum number of deployed instances when autoscaling."
}

variable "scale_cooldown" {
  type        = number
  description = "Number of seconds to wait before collecting data from a newly deployed instance."
}

variable "scale_cpu_target" {
  type        = number
  description = "CPU utilization to target when autoscaling. Should be between 0 and 1."
}