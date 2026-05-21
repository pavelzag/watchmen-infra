variable "name_prefix" {
  description = "Prefix used for the created Watchmen streaming resources."
  type        = string
  default     = "watchmen-live-trace"
}

variable "gcp_project_id" {
  description = "GCP project id that owns the Cloud Logging sink and Pub/Sub resources."
  type        = string
}

variable "gcp_region" {
  description = "Default region used for provider operations."
  type        = string
  default     = "us-central1"
}

variable "watchmen_push_url" {
  description = "Public HTTPS URL that forwards to your local Watchmen /api/ingest/gcp/pubsub endpoint."
  type        = string
}

variable "watchmen_push_audience" {
  description = "Optional OIDC audience for Pub/Sub push. Defaults to watchmen_push_url when empty."
  type        = string
  default     = ""
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
