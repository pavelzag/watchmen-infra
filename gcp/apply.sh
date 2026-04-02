#!/usr/bin/env bash
# Applies the live Terraform snapshot for watchmen-test-488807.
set -euo pipefail

cd "$(dirname "$0")"

PROJECT_VAR=""

for arg in "$@"; do
  case $arg in
    --project=*) PROJECT_VAR="-var=project_id=${arg#*=}" ;;
  esac
done

echo "→ Initialising Terraform..."
terraform init -upgrade

echo "→ Applying live snapshot..."
# shellcheck disable=SC2086
terraform apply -auto-approve $PROJECT_VAR

echo ""
echo "✓ Apply finished."
terraform output
