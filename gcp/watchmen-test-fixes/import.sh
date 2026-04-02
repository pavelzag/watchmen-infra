#!/usr/bin/env bash
# Import existing resources into state before applying.
# Run once from the watchmen-test-fixes/ directory after `terraform init`.
set -e

PROJECT="watchmen-test-488807"
REGION="us-central1"

echo "==> Importing firewall rules..."
terraform import google_compute_firewall.fix_default_allow_rdp        "projects/${PROJECT}/global/firewalls/default-allow-rdp"
terraform import google_compute_firewall.fix_default_allow_ssh        "projects/${PROJECT}/global/firewalls/default-allow-ssh"
terraform import google_compute_firewall.fix_wm_attack_allow_all_ingress "projects/${PROJECT}/global/firewalls/wm-attack-allow-all-ingress"
terraform import google_compute_firewall.fix_wm_attack_open_db_ports  "projects/${PROJECT}/global/firewalls/wm-attack-open-db-ports"
terraform import google_compute_firewall.fix_wm_attack_open_rdp       "projects/${PROJECT}/global/firewalls/wm-attack-open-rdp"
terraform import google_compute_firewall.fix_wm_attack_open_ssh       "projects/${PROJECT}/global/firewalls/wm-attack-open-ssh"

echo "==> Importing Cloud Run IAM..."
terraform import google_cloud_run_v2_service_iam_binding.fix_public_api_invoker          "projects/${PROJECT}/locations/${REGION}/services/wm-attack-public-api roles/run.invoker"
terraform import google_cloud_run_v2_service_iam_binding.fix_public_internal_api_invoker "projects/${PROJECT}/locations/${REGION}/services/wm-attack-public-internal-api roles/run.invoker"

echo "==> Importing storage buckets..."
terraform import google_storage_bucket.fix_uploads_bucket_policy    "${PROJECT}-wm-attack-public-uploads"
terraform import google_storage_bucket.fix_public_data_bucket_policy "${PROJECT}-wm-attack-public-data"
terraform import google_storage_bucket.fix_theinsite_images_bucket_policy "theinsite-scraped-images"

echo "==> Done. Run 'terraform plan' to verify, then 'terraform apply'."
