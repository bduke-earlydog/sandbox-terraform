terraform {
  required_version = ">= 1.5.6"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "4.80.0"
    }
  }
}

# Create a secret to store the PMM admin account password.
resource "google_secret_manager_secret" "pmm_admin_password_two" {
  secret_id = "pmm_admin_password"
  replication {
    automatic = true
  }
}

output "test" {
  value = google_secret_manager_secret.pmm_admin_password_two.secret_id
}