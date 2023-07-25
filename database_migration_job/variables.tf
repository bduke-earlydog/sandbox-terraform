variable "project_id" {
  type = string
  description = "The google cloud project id."
}

variable "enabled" {
  type = bool
  description = "Enable creation of the cloud build trigger and cloud run jobs for database migration."
}

variable "github_owner" {
  type = string
  description = "Organization or account that owns the source GitHub repository."
}

variable "github_repo" {
  type = string
  description = "Name of the source GitHub repository."
}

variable "github_branch" {
  type = string
  description = "Name of the source repository branch."
}

variable "image_name" {
    type = string
    description = "Name to use when creating and storing the generated container image."
}

