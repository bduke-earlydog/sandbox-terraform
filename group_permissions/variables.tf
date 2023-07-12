variable "project" {
  type        = string
  description = "Name of the project."
}

variable "roles" {
  type        = list(string)
  description = "List of roles to assign."
}

variable "group" {
  type        = string
  description = "The group to assign roles to."
}




