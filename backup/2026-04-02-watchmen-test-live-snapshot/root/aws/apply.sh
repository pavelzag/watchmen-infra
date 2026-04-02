#!/usr/bin/env bash
# Creates all Watchmen AWS test assets via Terraform.
# Usage: bash scripts/terraform/aws/apply.sh [--region=us-east-1] [--profile=your-profile]
set -euo pipefail

cd "$(dirname "$0")"

REGION_VAR=""
PROFILE_VAR=""

for arg in "$@"; do
  case $arg in
    --region=*) REGION_VAR="-var=aws_region=${arg#*=}" ;;
    --profile=*) PROFILE_VAR="-var=aws_profile=${arg#*=}" ;;
  esac
done

if [[ -z "${AWS_PROFILE:-}" && -z "${AWS_ACCESS_KEY_ID:-}" && -z "${PROFILE_VAR}" ]]; then
  cat <<'EOF'
No AWS credentials detected.

Use one of:
  AWS_PROFILE=<profile> bash aws/apply.sh
  bash aws/apply.sh --profile=<profile>
  export AWS_ACCESS_KEY_ID=...
  export AWS_SECRET_ACCESS_KEY=...

If you use AWS SSO, run: aws sso login --profile <profile>
EOF
  exit 1
fi

echo "→ Initialising Terraform..."
AWS_EC2_METADATA_DISABLED=true terraform init -upgrade

echo "→ Applying (RDS may take 5–10 min)..."
# shellcheck disable=SC2086
AWS_EC2_METADATA_DISABLED=true terraform apply -auto-approve $REGION_VAR $PROFILE_VAR

echo ""
echo "✓ Done. Trigger a Watchmen scan to see the new assets."
AWS_EC2_METADATA_DISABLED=true terraform output
