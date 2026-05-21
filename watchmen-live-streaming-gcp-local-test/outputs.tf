output "gcp_pubsub_topic_name" {
  value       = google_pubsub_topic.watchmen_live_trace.name
  description = "Pub/Sub topic receiving live GCP request logs."
}

output "gcp_pubsub_subscription_name" {
  value       = google_pubsub_subscription.watchmen_live_trace.name
  description = "Push subscription that forwards live request logs into Watchmen."
}

output "gcp_logging_sink_name" {
  value       = google_logging_project_sink.watchmen_live_trace.name
  description = "Cloud Logging sink that exports matching request logs."
}

output "watchmen_push_service_account_email" {
  value       = google_service_account.watchmen_pubsub_push.email
  description = "Service account Pub/Sub uses to mint OIDC tokens for Watchmen."
}
