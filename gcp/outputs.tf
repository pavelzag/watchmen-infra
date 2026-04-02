output "project_id" {
  value = var.project_id
}

output "service_accounts" {
  value = [
    google_service_account.etl.email,
    google_service_account.reporting.email,
    google_service_account.cicd.email,
    google_service_account.attack_escalation_sa.email,
    google_service_account.attack_owner_sa.email,
    google_service_account.attack_multikey_sa.email,
    google_service_account.attack_exposed_cicd.email,
    google_service_account.github_ci.email,
    google_service_account.watchmen_reader.email,
  ]
}

output "buckets" {
  value = [
    google_storage_bucket.logs.name,
    google_storage_bucket.data.name,
    google_storage_bucket.backups.name,
    google_storage_bucket.attack_public_data.name,
    google_storage_bucket.attack_public_uploads.name,
    google_storage_bucket.cloudbuild.name,
  ]
}

output "cloud_run_services" {
  value = [
    google_cloud_run_v2_service.hello.name,
    google_cloud_run_v2_service.api.name,
    google_cloud_run_v2_service.attack_leaked_aws_creds.name,
    google_cloud_run_v2_service.attack_stripe_key.name,
    google_cloud_run_v2_service.attack_github_token.name,
    google_cloud_run_v2_service.attack_db_password_env.name,
    google_cloud_run_v2_service.attack_public_internal_api.name,
    google_cloud_run_v2_service.attack_public_api.name,
  ]
}

output "compute_instances" {
  value = [
    google_compute_instance.test.name,
    google_compute_instance.attack_privileged_vm.name,
    google_compute_instance.attack_exposed_vm.name,
    google_compute_instance.attack_dev_instance.name,
  ]
}

output "pubsub_topics" {
  value = sort([for topic in google_pubsub_topic.topics : topic.name])
}

output "secret_names" {
  value = [
    google_secret_manager_secret.api_key.secret_id,
    google_secret_manager_secret.db_password.secret_id,
    google_secret_manager_secret.jwt_secret.secret_id,
  ]
}
