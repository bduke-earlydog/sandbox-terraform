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

variable "condition_title" {
  type        = string
  description = "A title that briefly indicates the purpose of the condition."
}

variable "condition_description" {
  type        = string
  description = "A full description that describes the conditional expression."
}

variable "condition_expression" {
  type        = string
  description = "Condition to apply using Common Expression Language syntax."
}