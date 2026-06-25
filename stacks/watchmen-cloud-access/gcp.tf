locals {
  gcp_services = toset([
    "artifactregistry.googleapis.com",
    "bigquery.googleapis.com",
    "cloudasset.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "cloudtrace.googleapis.com",
    "compute.googleapis.com",
    "container.googleapis.com",
    "containeranalysis.googleapis.com",
    "iam.googleapis.com",
    "logging.googleapis.com",
    "pubsub.googleapis.com",
    "run.googleapis.com",
    "secretmanager.googleapis.com",
    "sqladmin.googleapis.com",
    "storage.googleapis.com",
  ])

  gcp_project_roles = toset(concat([
    "roles/browser",
    "roles/viewer",
    "roles/iam.securityReviewer",
    "roles/logging.viewer",
    "roles/cloudtrace.user",
    "roles/containeranalysis.occurrences.viewer",
  ], var.gcp_extra_project_roles))
}

resource "google_project_service" "watchmen" {
  for_each = var.gcp_enable_services ? local.gcp_services : toset([])

  project            = var.gcp_project_id
  service            = each.value
  disable_on_destroy = false
}

resource "google_service_account" "watchmen_scanner" {
  project      = var.gcp_project_id
  account_id   = var.gcp_service_account_id
  display_name = "Watchmen Scanner"
  description  = "Read-only service account used by Watchmen for GCP scanning."

  depends_on = [google_project_service.watchmen]
}

resource "google_project_iam_member" "watchmen_scanner" {
  for_each = local.gcp_project_roles

  project = var.gcp_project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.watchmen_scanner.email}"
}

resource "google_service_account_key" "watchmen_scanner" {
  service_account_id = google_service_account.watchmen_scanner.name
}
