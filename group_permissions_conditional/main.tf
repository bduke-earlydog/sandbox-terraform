resource "google_project_iam_member" "project_iam_member" {
  for_each = var.roles
  project  = var.project
  role     = "roles/${each.value}"
  member   = "group:${var.group}"
  condition {
    title       = var.condition_title
    description = var.condition_description
    expression  = var.condition_expression
  }
}