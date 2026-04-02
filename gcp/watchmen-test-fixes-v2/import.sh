#!/usr/bin/env bash
# Import existing GCP resources into Terraform state before running apply.
# Run from this directory: bash import.sh

set -e

PROJECT="watchmen-test-488807"
REGION="us-central1"

echo "==> Importing Cloud SQL instance..."
terraform import google_sql_database_instance.fix_wm_test_sql "${PROJECT}/wm-test-sql"

echo "==> Importing project IAM binding: roles/storage.admin (watchmen-test)..."
terraform import google_project_iam_binding.fix_remove_etl_storage_admin "${PROJECT} roles/storage.admin"

echo "==> Importing storage buckets..."
terraform import google_storage_bucket.fix_logs_versioning "${PROJECT}-wm-logs"
terraform import google_storage_bucket.fix_data_versioning "${PROJECT}-wm-data"
terraform import google_storage_bucket.fix_backups_versioning "${PROJECT}-wm-backups"

echo "==> Importing theinsite project IAM bindings..."
terraform import google_project_iam_binding.fix_theinsite_remove_editor "theinsite roles/editor"
terraform import google_project_iam_binding.fix_theinsite_remove_storage_admin "theinsite roles/storage.admin"

echo "==> Importing theinsite buckets..."
terraform import google_storage_bucket.fix_theinsite_db_backups_versioning "theinsite-db-backups"
terraform import google_storage_bucket.fix_theinsite_assets_staging_versioning "theinsite-theinsite-assets-staging"

echo "==> All imports complete. Run: terraform plan"
