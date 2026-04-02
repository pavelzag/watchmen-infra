terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 7.0"
    }
  }
}

provider "google" {
  project = "watchmen-test-488807"
  region  = "us-central1"
}

# ============================================================================
# Watchmen Attack Path Remediation — watchmen-test-488807
#
# Addresses 19 of 20 attack paths from the Watchmen scan.
# The remaining path (user-lateral:zagalsky@gmail.com) spans 13 projects
# and requires manual review — see the comment at the bottom of this file.
# ============================================================================

# ── FIREWALL FIXES ────────────────────────────────────────────────────────────
# Restrict all open-internet firewall rules to internal range only.
# Addresses all 12 fw-vm-sa attack paths (6 firewalls × 2 VMs).

resource "google_compute_firewall" "fix_default_allow_rdp" {
  name          = "default-allow-rdp"
  network       = "default"
  direction     = "INGRESS"
  source_ranges = ["10.0.0.0/8"]

  allow {
    protocol = "tcp"
    ports    = ["3389"]
  }
}

resource "google_compute_firewall" "fix_default_allow_ssh" {
  name          = "default-allow-ssh"
  network       = "default"
  direction     = "INGRESS"
  source_ranges = ["10.0.0.0/8"]

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
}

resource "google_compute_firewall" "fix_wm_attack_allow_all_ingress" {
  name          = "wm-attack-allow-all-ingress"
  network       = "default"
  direction     = "INGRESS"
  source_ranges = ["10.0.0.0/8"]

  allow {
    protocol = "all"
  }
}

resource "google_compute_firewall" "fix_wm_attack_open_db_ports" {
  name          = "wm-attack-open-db-ports"
  network       = "default"
  direction     = "INGRESS"
  source_ranges = ["10.0.0.0/8"]

  allow {
    protocol = "tcp"
    ports    = ["3306", "5432", "27017", "6379"]
  }
}

resource "google_compute_firewall" "fix_wm_attack_open_rdp" {
  name          = "wm-attack-open-rdp"
  network       = "default"
  direction     = "INGRESS"
  source_ranges = ["10.0.0.0/8"]

  allow {
    protocol = "tcp"
    ports    = ["3389"]
  }
}

resource "google_compute_firewall" "fix_wm_attack_open_ssh" {
  name          = "wm-attack-open-ssh"
  network       = "default"
  direction     = "INGRESS"
  source_ranges = ["10.0.0.0/8"]

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
}

# ── SERVICE ACCOUNT PRIVILEGE FIXES ──────────────────────────────────────────
# Zero out editor/owner bindings for the three over-privileged SAs.
# Addresses: all fw-vm-sa, cloudrun-sa, and bucket-write-sa paths.
#
# NOTE: google_project_iam_binding is authoritative for the specified role —
# setting members = [] removes ALL members from that role on this project.
# Review the current binding before applying if other members hold these roles.

resource "google_project_iam_binding" "fix_remove_editor" {
  project = "watchmen-test-488807"
  role    = "roles/editor"
  members = []
}

resource "google_project_iam_binding" "fix_remove_owner" {
  project = "watchmen-test-488807"
  role    = "roles/owner"
  members = []
}

# Grant wm-test-cicd only the permissions it actually needs for CI/CD
resource "google_project_iam_member" "fix_cicd_sa_minimal" {
  project = "watchmen-test-488807"
  role    = "roles/cloudbuild.builds.builder"
  member  = "serviceAccount:wm-test-cicd@watchmen-test-488807.iam.gserviceaccount.com"

  depends_on = [google_project_iam_binding.fix_remove_editor]
}

# ── CLOUD RUN AUTHENTICATION FIXES ───────────────────────────────────────────
# Require authentication on both public Cloud Run services.
# Addresses: cloudrun-sa:wm-attack-public-api and cloudrun-sa:wm-attack-public-internal-api

resource "google_cloud_run_v2_service_iam_binding" "fix_public_api_invoker" {
  project  = "watchmen-test-488807"
  location = "us-central1"
  name     = "wm-attack-public-api"
  role     = "roles/run.invoker"
  members  = []
}

resource "google_cloud_run_v2_service_iam_binding" "fix_public_internal_api_invoker" {
  project  = "watchmen-test-488807"
  location = "us-central1"
  name     = "wm-attack-public-internal-api"
  role     = "roles/run.invoker"
  members  = []
}

# ── STORAGE BUCKET FIXES ──────────────────────────────────────────────────────
# Remove all public IAM bindings and enforce private access.
# Addresses: bucket-write-sa (uploads) and both bucket-read paths.

resource "google_storage_bucket_iam_binding" "fix_uploads_object_admin" {
  bucket  = "watchmen-test-488807-wm-attack-public-uploads"
  role    = "roles/storage.objectAdmin"
  members = []
}

resource "google_storage_bucket" "fix_uploads_bucket_policy" {
  name                        = "watchmen-test-488807-wm-attack-public-uploads"
  location                    = "US-CENTRAL1"
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"
}

resource "google_storage_bucket_iam_binding" "fix_public_data_object_viewer" {
  bucket  = "watchmen-test-488807-wm-attack-public-data"
  role    = "roles/storage.objectViewer"
  members = []
}

resource "google_storage_bucket" "fix_public_data_bucket_policy" {
  name                        = "watchmen-test-488807-wm-attack-public-data"
  location                    = "US-CENTRAL1"
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"
}

# theinsite-scraped-images is in the "theinsite" project — no project field needed
# for bucket IAM resources (bucket name is globally unique)
resource "google_storage_bucket_iam_binding" "fix_theinsite_images_viewer" {
  bucket  = "theinsite-scraped-images"
  role    = "roles/storage.objectViewer"
  members = []
}

resource "google_storage_bucket" "fix_theinsite_images_bucket_policy" {
  name                        = "theinsite-scraped-images"
  location                    = "US"
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"

  provider = google.theinsite
}

provider "google" {
  alias   = "theinsite"
  project = "theinsite"
  region  = "us-central1"
}

# ============================================================================
# NOT AUTOMATED: user-lateral:zagalsky@gmail.com
#
# zagalsky@gmail.com holds owner/editor across 13 projects. Removing this
# via Terraform (google_project_iam_binding with members = []) would zero out
# the owner/editor binding on every project — locking out all admins.
#
# Recommended manual steps:
#   1. Create a break-glass admin SA or add a second admin user first.
#   2. Replace personal owner/editor bindings with least-privilege roles
#      scoped to specific resources in each project.
#   3. Enable MFA and login alerts on zagalsky@gmail.com.
#   4. Run: gcloud projects get-iam-policy <project> to audit each project.
# ============================================================================
