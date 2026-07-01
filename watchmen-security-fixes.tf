terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 4.0.0"
    }
  }
}

provider "google" {
  project = "watchmen-test-488807"
}

resource "google_compute_firewall" "default-allow-icmp" {
  name    = "default-allow-icmp"
  project = "watchmen-test-488807"
  network = "default"

  allow {
    protocol = "icmp"
  }

  source_ranges = ["10.0.0.0/8"]

  description = "Allow ICMP traffic from internal RFC-1918 ranges only. Restricted from 0.0.0.0/0 to remediate 'Firewall Rule Open to the Internet' finding."
}