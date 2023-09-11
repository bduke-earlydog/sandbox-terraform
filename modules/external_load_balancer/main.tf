# Use the data sources from cloudflare and datadog providers to get lists of IP addresses to allow.
data "cloudflare_ip_ranges" "cloudflare" {}
data "datadog_ip_ranges" "datadog" {}

# Load balancer security rules.
# A rule can only contain 10 ip blocks, so we have to split the lists into sublists and make a rule for each.
resource "google_compute_security_policy" "policy" {
  project = var.project_id
  name    = "Cloud Armor security policy"

  dynamic "rule" {
    for_each = var.enable_default_deny == true ? ["${var.default_deny_code}"] : []
    content {
      description = "Default deny rule."
      action      = "deny(${rule.value})"
      priority    = "2147483647"
      match {
        versioned_expr = "SRC_IPS_V1"
        config {
          src_ip_ranges = ["*"]
        }
      }
    }
  }

  dynamic "rule" {
    for_each = chunklist(var.allow_cidr_blocks, 10)
    content {
      description = "Allow specific ipv4 blocks."
      action      = "allow"
      priority    = "1002"
      match {
        versioned_expr = "SRC_IPS_V1"
        config {
          src_ip_ranges = toset(rule.value)
        }
      }
    }
  }

  dynamic "rule" {
    for_each = var.allow_datadog_synthetics == true ? chunklist(data.datadog_ip_ranges.synthetics_ipv4, 10) : []
    content {
      description = "Allow Datadog synthetic endpoint ipv4 blocks."
      action      = "allow"
      priority    = "1001"
      match {
        versioned_expr = "SRC_IPS_V1"
        config {
          src_ip_ranges = toset(rule.value)
        }
      }
    }
  }

  dynamic "rule" {
    for_each = var.allow_cloudflare == true ? chunklist(data.cloudflare_ip_ranges.cloudflare.ipv4_cidr_blocks, 10) : []
    content {
      description = "Allow Cloudflare endpoint ipv4 blocks."
      action      = "allow"
      priority    = "1000"
      match {
        versioned_expr = "SRC_IPS_V1"
        config {
          src_ip_ranges = toset(rule.value)
        }
      }
    }
  }

}

resource "google_compute_backend_service" "load_balancer" {
  project               = var.project
  name                  = "${var.name}-load-balancer"
  load_balancing_scheme = "EXTERNAL"
  timeout_sec           = var.timeout
  health_checks         = var.health_checks
  security_policy       = google_compute_security_policy.policy.id
  log_config {
    enable = var.enable_logs
  }
  backend {
    group = var.instance_group
  }
}