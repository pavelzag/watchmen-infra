#!/usr/bin/env bash
# Destroys the AWS Watchmen test environment.
set -euo pipefail

cd "$(dirname "$0")"

AWS_REGION="${AWS_REGION:-us-east-1}"
NAME_PREFIX="${NAME_PREFIX:-wm-test}"
CREATE_ACCESS_KEYS="${CREATE_ACCESS_KEYS:-true}"
CREATE_EC2="${CREATE_EC2:-true}"
CREATE_RDS="${CREATE_RDS:-true}"
AUTO_APPROVE="${AUTO_APPROVE:-false}"

usage() {
  cat <<EOF
Usage: $0 [options]

Options:
  --region=REGION       AWS region. Default: $AWS_REGION
  --name-prefix=PREFIX  Resource prefix. Default: $NAME_PREFIX
  --no-access-keys      Match an apply that used --no-access-keys.
  --no-ec2              Match an apply that used --no-ec2.
  --no-rds              Match an apply that used --no-rds.
  --auto-approve        Destroy without an interactive approval prompt.
  -h, --help            Show this help.

Environment overrides:
  AWS_PROFILE, AWS_REGION, NAME_PREFIX, CREATE_ACCESS_KEYS, CREATE_EC2,
  CREATE_RDS, AUTO_APPROVE
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
    --auto-approve)
      AUTO_APPROVE="true"
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

echo "Checking AWS identity..."
CALLER_ARN="$(aws sts get-caller-identity --query Arn --output text)"
CALLER_ACCOUNT="$(aws sts get-caller-identity --query Account --output text)"
echo "AWS caller account: $CALLER_ACCOUNT"
echo "AWS caller ARN: $CALLER_ARN"

case "$CALLER_ARN" in
  *":user/watchmen-scanner"|*":user/service/watchmen/watchmen-scanner"|*":user/service/watchmen-test/watchmen-scanner")
    cat >&2 <<EOF
Refusing to destroy with watchmen-scanner.

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

terraform init

if [ "$AUTO_APPROVE" = "true" ]; then
  terraform destroy -auto-approve "${terraform_args[@]}"
else
  terraform destroy "${terraform_args[@]}"
fi
