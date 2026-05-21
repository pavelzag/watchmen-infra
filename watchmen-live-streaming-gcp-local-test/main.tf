terraform {
  required_version = ">= 1.5.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

provider "google" {
  project = var.gcp_project_id
  region  = var.gcp_region
}

data "google_project" "target" {
  project_id = var.gcp_project_id
}

resource "google_project_service" "pubsub_api" {
  project = var.gcp_project_id
  service = "pubsub.googleapis.com"
}

resource "google_project_service" "logging_api" {
  project = var.gcp_project_id
  service = "logging.googleapis.com"
}

resource "google_project_service" "iam_api" {
  project = var.gcp_project_id
  service = "iam.googleapis.com"
}

resource "google_pubsub_topic" "watchmen_live_trace" {
  project = var.gcp_project_id
  name    = "${var.name_prefix}-topic"

  depends_on = [
    google_project_service.pubsub_api,
  ]
}

resource "google_logging_project_sink" "watchmen_live_trace" {
  project                = var.gcp_project_id
  name                   = "${var.name_prefix}-sink"
  destination            = "pubsub.googleapis.com/projects/${var.gcp_project_id}/topics/${google_pubsub_topic.watchmen_live_trace.name}"
  filter                 = trimspace(var.gcp_log_filter)
  unique_writer_identity = true

  depends_on = [
    google_project_service.logging_api,
    google_pubsub_topic.watchmen_live_trace,
  ]
}

resource "google_pubsub_topic_iam_member" "watchmen_sink_publisher" {
  project = var.gcp_project_id
  topic   = google_pubsub_topic.watchmen_live_trace.name
  role    = "roles/pubsub.publisher"
  member  = google_logging_project_sink.watchmen_live_trace.writer_identity
}

resource "google_service_account" "watchmen_pubsub_push" {
  project      = var.gcp_project_id
  account_id   = substr(replace("${var.name_prefix}-push", "_", "-"), 0, 30)
  display_name = "Watchmen Pub/Sub push identity"

  depends_on = [
    google_project_service.iam_api,
  ]
}

resource "google_service_account_iam_member" "watchmen_pubsub_push_token_creator" {
  service_account_id = google_service_account.watchmen_pubsub_push.name
  role               = "roles/iam.serviceAccountTokenCreator"
  member             = "serviceAccount:service-${data.google_project.target.number}@gcp-sa-pubsub.iam.gserviceaccount.com"
}

resource "google_pubsub_subscription" "watchmen_live_trace" {
  project = var.gcp_project_id
  name    = "${var.name_prefix}-subscription"
  topic   = google_pubsub_topic.watchmen_live_trace.name

  ack_deadline_seconds       = var.gcp_subscription_ack_deadline_seconds
  message_retention_duration = var.gcp_message_retention_duration

  push_config {
    push_endpoint = var.watchmen_push_url
    attributes = {
      x-goog-version = "v1"
    }
    oidc_token {
      service_account_email = google_service_account.watchmen_pubsub_push.email
      audience              = trimspace(var.watchmen_push_audience) != "" ? var.watchmen_push_audience : var.watchmen_push_url
    }
  }

  depends_on = [
    google_pubsub_topic_iam_member.watchmen_sink_publisher,
    google_service_account_iam_member.watchmen_pubsub_push_token_creator,
  ]
}
