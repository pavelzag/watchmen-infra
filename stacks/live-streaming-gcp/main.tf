terraform {
  required_version = ">= 1.5.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

# -----------------------------------------------------------------------------
# Watchmen live trace streaming infrastructure for GCP
#
# Cloud Logging -> Log Router sink -> Pub/Sub topic -> Pub/Sub subscription
# -----------------------------------------------------------------------------

provider "google" {
  project = var.gcp_project_id
  region  = var.gcp_region
}

variable "name_prefix" {
  description = "Prefix used for created resources."
  type        = string
  default     = "watchmen-live-trace"
}

variable "gcp_project_id" {
  description = "GCP project id that owns the logging sink and Pub/Sub resources."
  type        = string
}

variable "gcp_region" {
  description = "GCP region for regional resources when needed."
  type        = string
  default     = "us-central1"
}

variable "gcp_log_filter" {
  description = "Cloud Logging filter for request-oriented live trace events."
  type        = string
  default     = <<-EOT
    resource.type="cloud_run_revision"
    OR resource.type="gce_instance"
    OR resource.type="k8s_container"
    OR resource.type="http_load_balancer"
  EOT
}

variable "gcp_subscription_ack_deadline_seconds" {
  description = "Ack deadline for the Watchmen Pub/Sub subscription."
  type        = number
  default     = 20
}

variable "gcp_message_retention_duration" {
  description = "How long Pub/Sub retains unacked messages."
  type        = string
  default     = "1200s"
}

variable "gcp_push_endpoint" {
  description = "Optional HTTPS endpoint for Pub/Sub push delivery. Leave empty to use a pull subscription."
  type        = string
  default     = ""
}

variable "gcp_push_audience" {
  description = "Optional OIDC audience for Pub/Sub push. Defaults to the push endpoint when empty."
  type        = string
  default     = ""
}

locals {
  gcp_push_enabled = trimspace(var.gcp_push_endpoint) != ""
}

resource "google_project_service" "gcp_pubsub_api" {
  project            = var.gcp_project_id
  service            = "pubsub.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "gcp_logging_api" {
  project            = var.gcp_project_id
  service            = "logging.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "gcp_iam_api" {
  project            = var.gcp_project_id
  service            = "iam.googleapis.com"
  disable_on_destroy = false
}

data "google_project" "gcp_project" {
  project_id = var.gcp_project_id
}

resource "google_pubsub_topic" "watchmen_live_trace" {
  project = var.gcp_project_id
  name    = "${var.name_prefix}-topic"

  depends_on = [
    google_project_service.gcp_pubsub_api,
  ]
}

resource "google_logging_project_sink" "watchmen_live_trace" {
  project                = var.gcp_project_id
  name                   = "${var.name_prefix}-sink"
  destination            = "pubsub.googleapis.com/projects/${var.gcp_project_id}/topics/${google_pubsub_topic.watchmen_live_trace.name}"
  filter                 = trimspace(var.gcp_log_filter)
  unique_writer_identity = true

  depends_on = [
    google_project_service.gcp_logging_api,
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
  count        = local.gcp_push_enabled ? 1 : 0
  project      = var.gcp_project_id
  account_id   = substr(replace("${var.name_prefix}-push", "_", "-"), 0, 30)
  display_name = "Watchmen Pub/Sub push identity"

  depends_on = [
    google_project_service.gcp_iam_api,
  ]
}

resource "google_service_account_iam_member" "watchmen_pubsub_push_token_creator" {
  count              = local.gcp_push_enabled ? 1 : 0
  service_account_id = google_service_account.watchmen_pubsub_push[0].name
  role               = "roles/iam.serviceAccountTokenCreator"
  member             = "serviceAccount:service-${data.google_project.gcp_project.number}@gcp-sa-pubsub.iam.gserviceaccount.com"
}

resource "google_pubsub_subscription" "watchmen_live_trace" {
  project = var.gcp_project_id
  name    = "${var.name_prefix}-subscription"
  topic   = google_pubsub_topic.watchmen_live_trace.name

  ack_deadline_seconds       = var.gcp_subscription_ack_deadline_seconds
  message_retention_duration = var.gcp_message_retention_duration

  dynamic "push_config" {
    for_each = local.gcp_push_enabled ? [1] : []
    content {
      push_endpoint = var.gcp_push_endpoint
      attributes = {
        x-goog-version = "v1"
      }
      oidc_token {
        service_account_email = google_service_account.watchmen_pubsub_push[0].email
        audience              = trimspace(var.gcp_push_audience) != "" ? var.gcp_push_audience : var.gcp_push_endpoint
      }
    }
  }

  depends_on = [
    google_pubsub_topic_iam_member.watchmen_sink_publisher,
    google_service_account_iam_member.watchmen_pubsub_push_token_creator,
  ]
}

output "gcp_pubsub_topic_name" {
  value       = google_pubsub_topic.watchmen_live_trace.name
  description = "Pub/Sub topic receiving live GCP request logs."
}

output "gcp_pubsub_subscription_name" {
  value       = google_pubsub_subscription.watchmen_live_trace.name
  description = "Pub/Sub subscription Watchmen should consume from."
}

output "gcp_logging_sink_writer_identity" {
  value       = google_logging_project_sink.watchmen_live_trace.writer_identity
  description = "Writer identity used by the GCP logging sink."
}
