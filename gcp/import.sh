#!/usr/bin/env bash
# Imports the current live watchmen-test-488807 snapshot into Terraform state.
set -uo pipefail

cd "$(dirname "$0")"

PROJECT="watchmen-test-488807"
ZONE="us-central1-a"
REGION="us-central1"
OWNER_EMAIL="zagalsky@gmail.com"

for arg in "$@"; do
  case $arg in
    --project=*) PROJECT="${arg#*=}" ;;
    --owner-email=*) OWNER_EMAIL="${arg#*=}" ;;
  esac
done

try_import() {
  local addr="$1" id="$2"
  if terraform state show "$addr" >/dev/null 2>&1; then
    echo "  skip (already managed): $addr"
  else
    terraform import "$addr" "$id"
  fi
}

echo "→ Importing live snapshot for project: $PROJECT"

# Service accounts
try_import google_service_account.etl "projects/$PROJECT/serviceAccounts/wm-test-etl@$PROJECT.iam.gserviceaccount.com"
try_import google_service_account.reporting "projects/$PROJECT/serviceAccounts/wm-test-reporting@$PROJECT.iam.gserviceaccount.com"
try_import google_service_account.cicd "projects/$PROJECT/serviceAccounts/wm-test-cicd@$PROJECT.iam.gserviceaccount.com"
try_import google_service_account.attack_escalation_sa "projects/$PROJECT/serviceAccounts/wm-attack-escalation-sa@$PROJECT.iam.gserviceaccount.com"
try_import google_service_account.attack_owner_sa "projects/$PROJECT/serviceAccounts/wm-attack-owner-sa@$PROJECT.iam.gserviceaccount.com"
try_import google_service_account.attack_multikey_sa "projects/$PROJECT/serviceAccounts/wm-attack-multikey-sa@$PROJECT.iam.gserviceaccount.com"
try_import google_service_account.attack_exposed_cicd "projects/$PROJECT/serviceAccounts/wm-attack-exposed-cicd@$PROJECT.iam.gserviceaccount.com"
try_import google_service_account.github_ci "projects/$PROJECT/serviceAccounts/github-ci@$PROJECT.iam.gserviceaccount.com"
try_import google_service_account.watchmen_reader "projects/$PROJECT/serviceAccounts/watchmen-reader@$PROJECT.iam.gserviceaccount.com"

# Project IAM
try_import 'google_project_iam_member.bindings["artifactregistry_service_agent"]' "$PROJECT roles/artifactregistry.serviceAgent serviceAccount:service-1018085780312@gcp-sa-artifactregistry.iam.gserviceaccount.com"
try_import 'google_project_iam_member.bindings["artifactregistry_writer_github_ci"]' "$PROJECT roles/artifactregistry.writer serviceAccount:github-ci@$PROJECT.iam.gserviceaccount.com"
try_import 'google_project_iam_member.bindings["bigquery_data_viewer_reporting"]' "$PROJECT roles/bigquery.dataViewer serviceAccount:wm-test-reporting@$PROJECT.iam.gserviceaccount.com"
try_import 'google_project_iam_member.bindings["bigquery_metadata_viewer_watchmen_reader"]' "$PROJECT roles/bigquery.metadataViewer serviceAccount:watchmen-reader@$PROJECT.iam.gserviceaccount.com"
try_import 'google_project_iam_member.bindings["cloudbuild_builder_default"]' "$PROJECT roles/cloudbuild.builds.builder serviceAccount:1018085780312@cloudbuild.gserviceaccount.com"
try_import 'google_project_iam_member.bindings["cloudbuild_builder_cicd"]' "$PROJECT roles/cloudbuild.builds.builder serviceAccount:wm-test-cicd@$PROJECT.iam.gserviceaccount.com"
try_import 'google_project_iam_member.bindings["cloudbuild_editor_cicd"]' "$PROJECT roles/cloudbuild.builds.editor serviceAccount:wm-test-cicd@$PROJECT.iam.gserviceaccount.com"
try_import 'google_project_iam_member.bindings["cloudbuild_editor_owner"]' "$PROJECT roles/cloudbuild.builds.editor user:$OWNER_EMAIL"
try_import 'google_project_iam_member.bindings["cloudbuild_service_agent"]' "$PROJECT roles/cloudbuild.serviceAgent serviceAccount:service-1018085780312@gcp-sa-cloudbuild.iam.gserviceaccount.com"
try_import 'google_project_iam_member.bindings["cloudsql_viewer_watchmen_reader"]' "$PROJECT roles/cloudsql.viewer serviceAccount:watchmen-reader@$PROJECT.iam.gserviceaccount.com"
try_import 'google_project_iam_member.bindings["cloudtrace_user_reporting"]' "$PROJECT roles/cloudtrace.user serviceAccount:wm-test-reporting@$PROJECT.iam.gserviceaccount.com"
try_import 'google_project_iam_member.bindings["compute_instance_group_manager_service_agent"]' "$PROJECT roles/compute.instanceGroupManagerServiceAgent serviceAccount:1018085780312@cloudservices.gserviceaccount.com"
try_import 'google_project_iam_member.bindings["compute_network_viewer_watchmen_reader"]' "$PROJECT roles/compute.networkViewer serviceAccount:watchmen-reader@$PROJECT.iam.gserviceaccount.com"
try_import 'google_project_iam_member.bindings["compute_service_agent"]' "$PROJECT roles/compute.serviceAgent serviceAccount:service-1018085780312@compute-system.iam.gserviceaccount.com"
try_import 'google_project_iam_member.bindings["container_default_node_service_agent"]' "$PROJECT roles/container.defaultNodeServiceAgent serviceAccount:service-1018085780312@gcp-sa-gkenode.iam.gserviceaccount.com"
try_import 'google_project_iam_member.bindings["container_service_agent"]' "$PROJECT roles/container.serviceAgent serviceAccount:service-1018085780312@container-engine-robot.iam.gserviceaccount.com"
try_import 'google_project_iam_member.bindings["container_viewer_watchmen_reader"]' "$PROJECT roles/container.viewer serviceAccount:watchmen-reader@$PROJECT.iam.gserviceaccount.com"
try_import 'google_project_iam_member.bindings["containeranalysis_service_agent"]' "$PROJECT roles/containeranalysis.ServiceAgent serviceAccount:service-1018085780312@container-analysis.iam.gserviceaccount.com"
try_import 'google_project_iam_member.bindings["containeranalysis_admin_watchmen_reader"]' "$PROJECT roles/containeranalysis.admin serviceAccount:watchmen-reader@$PROJECT.iam.gserviceaccount.com"
try_import 'google_project_iam_member.bindings["containeranalysis_occurrences_viewer_watchmen_reader"]' "$PROJECT roles/containeranalysis.occurrences.viewer serviceAccount:watchmen-reader@$PROJECT.iam.gserviceaccount.com"
try_import 'google_project_iam_member.bindings["containerregistry_service_agent"]' "$PROJECT roles/containerregistry.ServiceAgent serviceAccount:service-1018085780312@containerregistry.iam.gserviceaccount.com"
try_import 'google_project_iam_member.bindings["containerscanning_service_agent"]' "$PROJECT roles/containerscanning.ServiceAgent serviceAccount:service-1018085780312@gcp-sa-containerscanning.iam.gserviceaccount.com"
try_import 'google_project_iam_member.bindings["editor_attack_escalation"]' "$PROJECT roles/editor serviceAccount:wm-attack-escalation-sa@$PROJECT.iam.gserviceaccount.com"
try_import 'google_project_iam_member.bindings["editor_attack_exposed_cicd"]' "$PROJECT roles/editor serviceAccount:wm-attack-exposed-cicd@$PROJECT.iam.gserviceaccount.com"
try_import 'google_project_iam_member.bindings["iam_security_reviewer_reporting"]' "$PROJECT roles/iam.securityReviewer serviceAccount:wm-test-reporting@$PROJECT.iam.gserviceaccount.com"
try_import 'google_project_iam_member.bindings["iam_security_reviewer_watchmen_reader"]' "$PROJECT roles/iam.securityReviewer serviceAccount:watchmen-reader@$PROJECT.iam.gserviceaccount.com"
try_import 'google_project_iam_member.bindings["networkconnectivity_service_agent"]' "$PROJECT roles/networkconnectivity.serviceAgent serviceAccount:service-1018085780312@gcp-sa-networkconnectivity.iam.gserviceaccount.com"
try_import 'google_project_iam_member.bindings["owner_attack_owner_sa"]' "$PROJECT roles/owner serviceAccount:wm-attack-owner-sa@$PROJECT.iam.gserviceaccount.com"
try_import 'google_project_iam_member.bindings["owner_user"]' "$PROJECT roles/owner user:$OWNER_EMAIL"
try_import 'google_project_iam_member.bindings["pubsub_service_agent"]' "$PROJECT roles/pubsub.serviceAgent serviceAccount:service-1018085780312@gcp-sa-pubsub.iam.gserviceaccount.com"
try_import 'google_project_iam_member.bindings["pubsub_viewer_watchmen_reader"]' "$PROJECT roles/pubsub.viewer serviceAccount:watchmen-reader@$PROJECT.iam.gserviceaccount.com"
try_import 'google_project_iam_member.bindings["run_service_agent"]' "$PROJECT roles/run.serviceAgent serviceAccount:service-1018085780312@serverless-robot-prod.iam.gserviceaccount.com"
try_import 'google_project_iam_member.bindings["run_viewer_watchmen_reader"]' "$PROJECT roles/run.viewer serviceAccount:watchmen-reader@$PROJECT.iam.gserviceaccount.com"
try_import 'google_project_iam_member.bindings["secretmanager_viewer_watchmen_reader"]' "$PROJECT roles/secretmanager.viewer serviceAccount:watchmen-reader@$PROJECT.iam.gserviceaccount.com"
try_import 'google_project_iam_member.bindings["storage_object_viewer_watchmen_reader"]' "$PROJECT roles/storage.objectViewer serviceAccount:watchmen-reader@$PROJECT.iam.gserviceaccount.com"
try_import 'google_project_iam_member.bindings["viewer_reporting"]' "$PROJECT roles/viewer serviceAccount:wm-test-reporting@$PROJECT.iam.gserviceaccount.com"

# Keys
for key_id in \
  e50e30798818421e2a8345762454d6146fb18283 \
  3439894292c9a2a4893a958f0578d29b1f644c11 \
  f80d998649c2ac3fe0d2476971d0b16c34d5a8ad \
  5c2fa672b7ba5c6f86e34dbe05b16e713ab46697 \
  9df49c03ebd9cee88df9ea8b37fda6cb1091bcf3 \
  50104a6e58352e5f8e94402a062802d48ffdbe30 \
  abdc06eab86ec3d9f9238a2ef58e81d2856421e5 \
  f07b6122426cd4bf390783722279d96abb93ad3b \
  726aa72562a38f0c651f6c8115465e16a1937ecb; do
  try_import "google_service_account_key.attack_multikey[\"$key_id\"]" "projects/$PROJECT/serviceAccounts/wm-attack-multikey-sa@$PROJECT.iam.gserviceaccount.com/keys/$key_id"
done

for key_id in \
  698c988d677648eb63c4c11a3b5af83e0f9982fd \
  7b85293e10467c925997086f138619ba3c78bbd7 \
  eccf7fa0f3ac1bfde9154f993d6c07ca5f11d529 \
  88633fca45515589538996dd73201d84613d0e38 \
  5e2dbda2d95e1307472a04ec1b21452675385215 \
  286fd3d85b45eccdd727f367044abc8bc69d2fc2; do
  try_import "google_service_account_key.attack_exposed_cicd[\"$key_id\"]" "projects/$PROJECT/serviceAccounts/wm-attack-exposed-cicd@$PROJECT.iam.gserviceaccount.com/keys/$key_id"
done

# Storage
try_import google_storage_bucket.logs "$PROJECT-wm-logs"
try_import google_storage_bucket.data "$PROJECT-wm-data"
try_import google_storage_bucket.backups "$PROJECT-wm-backups"
try_import google_storage_bucket.attack_public_data "$PROJECT-wm-attack-public-data"
try_import google_storage_bucket.attack_public_uploads "$PROJECT-wm-attack-public-uploads"
try_import google_storage_bucket.cloudbuild "${PROJECT}_cloudbuild"
try_import google_storage_bucket_iam_member.etl_logs_object_admin "$PROJECT-wm-logs roles/storage.objectAdmin serviceAccount:wm-test-etl@$PROJECT.iam.gserviceaccount.com"
try_import google_storage_bucket_iam_member.etl_data_object_admin "$PROJECT-wm-data roles/storage.objectAdmin serviceAccount:wm-test-etl@$PROJECT.iam.gserviceaccount.com"

# Compute + GKE
try_import google_compute_firewall.default_allow_icmp "projects/$PROJECT/global/firewalls/default-allow-icmp"
try_import google_compute_firewall.default_allow_internal "projects/$PROJECT/global/firewalls/default-allow-internal"
try_import google_compute_firewall.default_allow_rdp "projects/$PROJECT/global/firewalls/default-allow-rdp"
try_import google_compute_firewall.default_allow_ssh "projects/$PROJECT/global/firewalls/default-allow-ssh"
try_import google_compute_firewall.allow_internal "projects/$PROJECT/global/firewalls/wm-test-allow-internal"
try_import google_compute_firewall.allow_iap_ssh "projects/$PROJECT/global/firewalls/wm-test-allow-iap-ssh"
try_import google_compute_firewall.allow_http_open "projects/$PROJECT/global/firewalls/wm-test-allow-http-open"
try_import google_compute_firewall.attack_open_ssh "projects/$PROJECT/global/firewalls/wm-attack-open-ssh"
try_import google_compute_firewall.attack_open_rdp "projects/$PROJECT/global/firewalls/wm-attack-open-rdp"
try_import google_compute_firewall.attack_open_db_ports "projects/$PROJECT/global/firewalls/wm-attack-open-db-ports"
try_import google_compute_firewall.attack_allow_all "projects/$PROJECT/global/firewalls/wm-attack-allow-all-ingress"
try_import google_container_cluster.test "$PROJECT/$ZONE/wm-test-cluster"
try_import google_container_node_pool.primary_nodes "$PROJECT/$ZONE/wm-test-cluster/wm-test-node-pool"
try_import google_compute_instance.test "projects/$PROJECT/zones/$ZONE/instances/wm-test-vm"
try_import google_compute_instance.attack_privileged_vm "projects/$PROJECT/zones/$ZONE/instances/wm-attack-privileged-vm"
try_import google_compute_instance.attack_exposed_vm "projects/$PROJECT/zones/$ZONE/instances/wm-attack-exposed-vm"
try_import google_compute_instance.attack_dev_instance "projects/$PROJECT/zones/$ZONE/instances/wm-attack-dev-instance"

# Cloud Run
try_import google_cloud_run_v2_service.hello "projects/$PROJECT/locations/$REGION/services/wm-test-hello"
try_import google_cloud_run_v2_service.api "projects/$PROJECT/locations/$REGION/services/wm-test-api"
try_import google_cloud_run_v2_service.attack_leaked_aws_creds "projects/$PROJECT/locations/$REGION/services/wm-attack-leaked-aws-creds"
try_import google_cloud_run_v2_service.attack_stripe_key "projects/$PROJECT/locations/$REGION/services/wm-attack-stripe-key"
try_import google_cloud_run_v2_service.attack_github_token "projects/$PROJECT/locations/$REGION/services/wm-attack-github-runner"
try_import google_cloud_run_v2_service.attack_db_password_env "projects/$PROJECT/locations/$REGION/services/wm-attack-db-password-env"
try_import google_cloud_run_v2_service.attack_public_internal_api "projects/$PROJECT/locations/$REGION/services/wm-attack-public-internal-api"
try_import google_cloud_run_v2_service.attack_public_api "projects/$PROJECT/locations/$REGION/services/wm-attack-public-api"

# Data services
try_import google_sql_database_instance.test "$PROJECT/wm-test-sql"
try_import google_bigquery_dataset.analytics "projects/$PROJECT/datasets/wm_test_analytics"
try_import google_bigquery_dataset.logs "projects/$PROJECT/datasets/wm_test_logs"
try_import google_bigquery_dataset.ml_features "projects/$PROJECT/datasets/wm_test_ml_features"
try_import 'google_pubsub_topic.topics["wm-test-alerts"]' "projects/$PROJECT/topics/wm-test-alerts"
try_import 'google_pubsub_topic.topics["wm-test-events"]' "projects/$PROJECT/topics/wm-test-events"
try_import 'google_pubsub_topic.topics["wm-test-metrics"]' "projects/$PROJECT/topics/wm-test-metrics"
try_import 'google_pubsub_topic.topics["container-analysis-notes-v1"]' "projects/$PROJECT/topics/container-analysis-notes-v1"
try_import 'google_pubsub_topic.topics["container-analysis-occurrences-v1"]' "projects/$PROJECT/topics/container-analysis-occurrences-v1"
try_import 'google_pubsub_topic.topics["container-analysis-notes-v1beta1"]' "projects/$PROJECT/topics/container-analysis-notes-v1beta1"
try_import 'google_pubsub_topic.topics["container-analysis-occurrences-v1beta1"]' "projects/$PROJECT/topics/container-analysis-occurrences-v1beta1"
try_import google_secret_manager_secret.api_key "projects/$PROJECT/secrets/wm-test-api-key"
try_import google_secret_manager_secret.db_password "projects/$PROJECT/secrets/wm-test-db-password"
try_import google_secret_manager_secret.jwt_secret "projects/$PROJECT/secrets/wm-test-jwt-secret"

echo ""
echo "✓ Import complete. Secret versions are intentionally not codified in Terraform because their payloads are opaque."
