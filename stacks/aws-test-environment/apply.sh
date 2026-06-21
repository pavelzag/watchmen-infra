#!/usr/bin/env bash
# Creates the AWS Watchmen test environment: IAM, storage, Lambda/API Gateway,
# VPC/security groups, optional EC2 test VMs, optional RDS, queues, topics, and secrets.
set -euo pipefail

cd "$(dirname "$0")"

AWS_REGION="${AWS_REGION:-us-east-1}"
NAME_PREFIX="${NAME_PREFIX:-wm-test}"
CREATE_ACCESS_KEYS="${CREATE_ACCESS_KEYS:-true}"
CREATE_EC2="${CREATE_EC2:-true}"
CREATE_RDS="${CREATE_RDS:-true}"
AUTO_APPROVE="${AUTO_APPROVE:-true}"
INIT_UPGRADE="${INIT_UPGRADE:-false}"

usage() {
  cat <<EOF
Usage: $0 [options]

Options:
  --region=REGION       AWS region. Default: $AWS_REGION
  --name-prefix=PREFIX  Resource prefix. Default: $NAME_PREFIX
  --no-access-keys      Do not create IAM access keys.
  --no-ec2              Skip EC2 test VMs. Useful while an AWS account is blocked from RunInstances.
  --no-rds              Skip the public RDS MySQL test instance.
  --plan-only           Run terraform plan instead of apply.
  --init-upgrade        Run terraform init -upgrade.
  -h, --help            Show this help.

Environment overrides:
  AWS_PROFILE, AWS_REGION, NAME_PREFIX, CREATE_ACCESS_KEYS, CREATE_EC2,
  CREATE_RDS, AUTO_APPROVE, INIT_UPGRADE
EOF
}

for arg in "$@"; do
  case "$arg" in
    --region=*)
      AWS_REGION="${arg#*=}"
      ;;
    --name-prefix=*)
      NAME_PREFIX="${arg#*=}"
      ;;
    --no-access-keys)
      CREATE_ACCESS_KEYS="false"
      ;;
    --no-ec2)
      CREATE_EC2="false"
      ;;
    --no-rds)
      CREATE_RDS="false"
      ;;
    --plan-only)
      AUTO_APPROVE="false"
      ;;
    --init-upgrade)
      INIT_UPGRADE="true"
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $arg" >&2
      usage >&2
      exit 2
      ;;
  esac
done

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required command: $1" >&2
    exit 1
  fi
}

require_command terraform
require_command aws

echo "Checking AWS identity..."
CALLER_ARN="$(aws sts get-caller-identity --query Arn --output text)"
CALLER_ACCOUNT="$(aws sts get-caller-identity --query Account --output text)"
echo "AWS caller account: $CALLER_ACCOUNT"
echo "AWS caller ARN: $CALLER_ARN"

case "$CALLER_ARN" in
  *":user/watchmen-scanner"|*":user/service/watchmen/watchmen-scanner"|*":user/service/watchmen-test/watchmen-scanner")
    cat >&2 <<EOF
Refusing to apply with watchmen-scanner.

watchmen-scanner is the Watchmen UI scanner user and should only read cloud
inventory/logs. Use the infrastructure admin identity instead, for example:

  AWS_PROFILE=watchmen-terraform-admin $0
EOF
    exit 1
    ;;
esac

terraform_args=(
  -var="aws_region=$AWS_REGION"
  -var="name_prefix=$NAME_PREFIX"
  -var="create_access_keys=$CREATE_ACCESS_KEYS"
  -var="create_ec2=$CREATE_EC2"
  -var="create_rds=$CREATE_RDS"
)

echo "Initialising Terraform..."
if [ "$INIT_UPGRADE" = "true" ]; then
  terraform init -upgrade
else
  terraform init
fi

if [ "$AUTO_APPROVE" = "true" ]; then
  echo "Applying AWS test environment..."
  terraform apply -auto-approve "${terraform_args[@]}"
else
  echo "Planning AWS test environment..."
  terraform plan "${terraform_args[@]}"
  exit 0
fi

echo ""
echo "Terraform outputs:"
terraform output

echo ""
echo "External Lambda/API Gateway base URL:"
terraform output -raw http_api_base_url

if [ "$CREATE_EC2" = "true" ]; then
  echo ""
  echo "External EC2 test URLs:"
  terraform output ec2_test_urls
fi
