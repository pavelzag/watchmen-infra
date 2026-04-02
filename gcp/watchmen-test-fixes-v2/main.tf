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

provider "google" {
  alias   = "theinsite"
  project = "theinsite"
  region  = "us-central1"
}

# ============================================================================
# Watchmen Attack Path Remediation v2 — remaining issues after v1
#
# Addresses issues visible in Watchmen snapshot after watchmen-test-fixes v1:
#   - Cloud SQL backups disabled + public IP without SSL enforcement
#   - wm-test-etl holding roles/storage.admin (too broad)
#   - theinsite: default compute SA holding roles/editor
#   - theinsite: github-actions-sa holding roles/storage.admin
#   - Watchmen-test buckets missing versioning
#
# NOT AUTOMATED (require manual review):
#   - zagalsky@gmail.com owner across 13 projects — see note at bottom
#   - Legacy project SA owners (shiftmanagerapi, raspgen-spreadsheet,
#     camvision-188315, api-8868282396434458803-112515) — separate projects,
#     review each before removing to avoid lockout
# ============================================================================

# ── CLOUD SQL ─────────────────────────────────────────────────────────────────
# Enable automated backups and enforce SSL on wm-test-sql.

resource "google_sql_database_instance" "fix_wm_test_sql" {
  name             = "wm-test-sql"
  database_version = "MYSQL_8_0"
  region           = "us-central1"

  deletion_protection = false

  settings {
    tier              = "db-f1-micro"
    availability_type = "ZONAL"
    disk_autoresize   = false
    disk_size         = 10
    disk_type         = "PD_SSD"

    # Enable automated backups — addresses "backupEnabled: false" finding
    backup_configuration {
      enabled            = true
      binary_log_enabled = true # required for PITR with MySQL
      start_time         = "03:00"
    }

    ip_configuration {
      # Public IP required (no VPC peering configured for private IP).
      # No authorized_networks = accessible only via Cloud SQL Auth Proxy.
      ipv4_enabled = true
      ssl_mode = "ENCRYPTED_ONLY"
    }
  }
}

# ── ETL SERVICE ACCOUNT — REDUCE FROM storage.admin ──────────────────────────
# wm-test-etl only needs to read/write objects, not manage buckets.
# Replace roles/storage.admin with objectAdmin scoped to specific buckets.

resource "google_project_iam_binding" "fix_remove_etl_storage_admin" {
  project = "watchmen-test-488807"
  role    = "roles/storage.admin"
  # Remove all members — storage.admin is too broad (grants bucket deletion, ACL changes)
  members = []
}

resource "google_storage_bucket_iam_member" "fix_etl_data_bucket" {
  bucket = "watchmen-test-488807-wm-data"
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:wm-test-etl@watchmen-test-488807.iam.gserviceaccount.com"

  depends_on = [google_project_iam_binding.fix_remove_etl_storage_admin]
}

resource "google_storage_bucket_iam_member" "fix_etl_logs_bucket" {
  bucket = "watchmen-test-488807-wm-logs"
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:wm-test-etl@watchmen-test-488807.iam.gserviceaccount.com"

  depends_on = [google_project_iam_binding.fix_remove_etl_storage_admin]
}

# ── WATCHMEN-TEST BUCKET VERSIONING ──────────────────────────────────────────
# Enable versioning on the three watchmen-test storage buckets.

resource "google_storage_bucket" "fix_logs_versioning" {
  name          = "watchmen-test-488807-wm-logs"
  location      = "US-CENTRAL1"
  storage_class = "NEARLINE"
  force_destroy = true

  uniform_bucket_level_access = true

  versioning {
    enabled = true
  }

  lifecycle_rule {
    action { type = "Delete" }
    condition { age = 30 }
  }
}

resource "google_storage_bucket" "fix_data_versioning" {
  name          = "watchmen-test-488807-wm-data"
  location      = "US-CENTRAL1"
  storage_class = "NEARLINE"
  force_destroy = true

  uniform_bucket_level_access = true

  versioning {
    enabled = true
  }
}

resource "google_storage_bucket" "fix_backups_versioning" {
  name          = "watchmen-test-488807-wm-backups"
  location      = "US-CENTRAL1"
  storage_class = "ARCHIVE"
  force_destroy = true

  uniform_bucket_level_access = true

  versioning {
    enabled = true
  }
}

# ── THEINSITE PROJECT — COMPUTE DEFAULT SA ───────────────────────────────────
# The default compute SA (65648195841-compute@developer.gserviceaccount.com)
# holds roles/editor on theinsite. Remove editor and grant only what's needed.
#
# WARNING: This is an authoritative binding — it will remove ALL members from
# roles/editor on the theinsite project. Verify no other resources depend on
# this binding before applying.

resource "google_project_iam_binding" "fix_theinsite_remove_editor" {
  provider = google.theinsite
  project  = "theinsite"
  role     = "roles/editor"
  members  = []
}

# Re-grant the compute SA only Compute Instance Admin (what it typically needs)
resource "google_project_iam_member" "fix_theinsite_compute_sa_minimal" {
  provider = google.theinsite
  project  = "theinsite"
  role     = "roles/compute.instanceAdmin.v1"
  member   = "serviceAccount:65648195841-compute@developer.gserviceaccount.com"

  depends_on = [google_project_iam_binding.fix_theinsite_remove_editor]
}

# ── THEINSITE PROJECT — GITHUB ACTIONS SA ────────────────────────────────────
# github-actions-sa@theinsite.iam.gserviceaccount.com has roles/storage.admin.
# Replace with objectAdmin scoped to the specific deployment buckets.

resource "google_project_iam_binding" "fix_theinsite_remove_storage_admin" {
  provider = google.theinsite
  project  = "theinsite"
  role     = "roles/storage.admin"
  members  = []
}

# Grant narrow objectAdmin on specific theinsite buckets
resource "google_storage_bucket_iam_member" "fix_github_actions_assets_staging" {
  bucket   = "theinsite-theinsite-assets-staging"
  role     = "roles/storage.objectAdmin"
  member   = "serviceAccount:github-actions-sa@theinsite.iam.gserviceaccount.com"

  depends_on = [google_project_iam_binding.fix_theinsite_remove_storage_admin]
}

resource "google_storage_bucket_iam_member" "fix_github_actions_db_backups" {
  bucket   = "theinsite-db-backups"
  role     = "roles/storage.objectAdmin"
  member   = "serviceAccount:github-actions-sa@theinsite.iam.gserviceaccount.com"

  depends_on = [google_project_iam_binding.fix_theinsite_remove_storage_admin]
}

# ── THEINSITE BUCKET VERSIONING ───────────────────────────────────────────────
# Enable versioning on theinsite buckets that are missing it.

resource "google_storage_bucket" "fix_theinsite_db_backups_versioning" {
  provider      = google.theinsite
  name          = "theinsite-db-backups"
  location      = "US"
  force_destroy = false

  uniform_bucket_level_access = true

  versioning {
    enabled = true
  }
}

resource "google_storage_bucket" "fix_theinsite_assets_staging_versioning" {
  provider      = google.theinsite
  name          = "theinsite-theinsite-assets-staging"
  location      = "US"
  force_destroy = false

  uniform_bucket_level_access = true

  versioning {
    enabled = true
  }
}

# ============================================================================
# NOT AUTOMATED: zagalsky@gmail.com owner across 13 projects
#
# zagalsky@gmail.com holds owner/editor on 13 projects. Removing via
# google_project_iam_binding with members = [] would zero out ALL owners on
# each project — potentially locking out all admins.
#
# Manual steps before automating:
#   1. For each project, confirm there is at least one other owner/admin.
#   2. Replace the personal account with a dedicated admin SA or group.
#   3. Run: gcloud projects get-iam-policy <project> --format=json
#   4. Downgrade to roles/viewer on inactive projects, revoke on stale ones.
#
# NOT AUTOMATED: Legacy project SA owners
# (shiftmanagerapi, raspgen-spreadsheet, camvision-188315,
#  api-8868282396434458803-112515)
#
# These SAs hold roles/owner on their respective projects. Before removing:
#   1. Verify the projects are still active.
#   2. Check if any automation depends on owner-level access.
#   3. Replace with least-privilege roles using:
#      gcloud projects get-iam-policy <project>
#   4. Then add a google_project_iam_binding block for each role with the
#      corrected members list.
# ============================================================================
