variable "project_id" {
  type        = string
  description = "The google cloud project id."
}

variable "project_num" {
  type        = string
  description = "The google cloud project number."
}

variable "location" {
  type        = string
  description = "The location to create resources in."
}

variable "github_owner" {
  type        = string
  description = "Organization or account that owns the source GitHub repository."
}

variable "github_repo" {
  type        = string
  description = "Name of the source GitHub repository."
}

variable "github_branch" {
  type        = string
  description = "Name of the source repository branch."
}

variable "image_name" {
  type        = string
  description = "Name to use when creating and storing the generated container image."
}

