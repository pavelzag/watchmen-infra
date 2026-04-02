resource "google_storage_bucket" "logs" {
  name          = "${var.project_id}-wm-logs"
  location      = "US-CENTRAL1"
  storage_class = "NEARLINE"
  force_destroy = true

  public_access_prevention    = "inherited"
  uniform_bucket_level_access = true

  versioning {
    enabled = true
  }

  lifecycle_rule {
    action {
      type = "Delete"
    }

    condition {
      age = 30
    }
  }
}

resource "google_storage_bucket" "data" {
  name          = "${var.project_id}-wm-data"
  location      = "US-CENTRAL1"
  storage_class = "NEARLINE"
  force_destroy = true

  public_access_prevention    = "inherited"
  uniform_bucket_level_access = true

  versioning {
    enabled = true
  }
}

resource "google_storage_bucket" "backups" {
  name          = "${var.project_id}-wm-backups"
  location      = "US-CENTRAL1"
  storage_class = "ARCHIVE"
  force_destroy = true

  public_access_prevention    = "inherited"
  uniform_bucket_level_access = true

  versioning {
    enabled = true
  }
}

resource "google_storage_bucket" "attack_public_data" {
  name          = "${var.project_id}-wm-attack-public-data"
  location      = "US-CENTRAL1"
  storage_class = "STANDARD"
  force_destroy = true

  public_access_prevention    = "enforced"
  uniform_bucket_level_access = true
}

resource "google_storage_bucket" "attack_public_uploads" {
  name          = "${var.project_id}-wm-attack-public-uploads"
  location      = "US-CENTRAL1"
  storage_class = "STANDARD"
  force_destroy = true

  public_access_prevention    = "enforced"
  uniform_bucket_level_access = true
}

resource "google_storage_bucket" "cloudbuild" {
  name          = "${var.project_id}_cloudbuild"
  location      = "US"
  storage_class = "STANDARD"
  force_destroy = false

  public_access_prevention    = "inherited"
  uniform_bucket_level_access = false
}

resource "google_storage_bucket_iam_member" "etl_logs_object_admin" {
  bucket = google_storage_bucket.logs.name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.etl.email}"
}

resource "google_storage_bucket_iam_member" "etl_data_object_admin" {
  bucket = google_storage_bucket.data.name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.etl.email}"
}
