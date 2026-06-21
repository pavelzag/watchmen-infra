#!/usr/bin/env bash
# Destroys cost-bearing AWS test assets created by this repo.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

AWS_REGION="${AWS_REGION:-us-east-1}"
EKS_CLUSTER_NAME="${EKS_CLUSTER_NAME:-watchmen-test}"
WATCHMEN_NAMESPACE="${WATCHMEN_NAMESPACE:-watchmen}"
NAME_PREFIX="${NAME_PREFIX:-wm-test}"
AUTO_APPROVE="${AUTO_APPROVE:-false}"
DESTROY_EKS="${DESTROY_EKS:-true}"
DESTROY_TEST_ENVIRONMENT="${DESTROY_TEST_ENVIRONMENT:-true}"

usage() {
  cat <<EOF
Usage: $0 [options]

Destroys the cost-bearing AWS test assets managed by:
  - stacks/aws-eks-cluster
  - stacks/aws-test-environment

The aws-watchmen-user stack is intentionally not destroyed by this script
because IAM users and access keys do not create hourly infrastructure cost.

Options:
  --region=REGION          AWS region. Default: $AWS_REGION
  --eks-cluster=NAME       EKS cluster name. Default: $EKS_CLUSTER_NAME
  --namespace=NAME         Kubernetes namespace for Watchmen services. Default: $WATCHMEN_NAMESPACE
  --name-prefix=PREFIX     AWS test environment name prefix. Default: $NAME_PREFIX
  --skip-eks               Do not destroy stacks/aws-eks-cluster.
  --skip-test-environment  Do not destroy stacks/aws-test-environment.
  --auto-approve           Destroy without Terraform approval prompts.
  -h, --help               Show this help.

Environment overrides:
  AWS_PROFILE, AWS_REGION, EKS_CLUSTER_NAME, WATCHMEN_NAMESPACE, NAME_PREFIX,
  AUTO_APPROVE, DESTROY_EKS, DESTROY_TEST_ENVIRONMENT
EOF
}

for arg in "$@"; do
  case "$arg" in
    --region=*)
      AWS_REGION="${arg#*=}"
      ;;
    --eks-cluster=*)
      EKS_CLUSTER_NAME="${arg#*=}"
      ;;
    --namespace=*)
      WATCHMEN_NAMESPACE="${arg#*=}"
      ;;
    --name-prefix=*)
      NAME_PREFIX="${arg#*=}"
      ;;
    --skip-eks)
      DESTROY_EKS="false"
      ;;
    --skip-test-environment)
      DESTROY_TEST_ENVIRONMENT="false"
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
caller_arn="$(aws sts get-caller-identity --query Arn --output text)"
caller_account="$(aws sts get-caller-identity --query Account --output text)"
echo "AWS caller account: $caller_account"
echo "AWS caller ARN: $caller_arn"

case "$caller_arn" in
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

tf_destroy_args=()
if [ "$AUTO_APPROVE" = "true" ]; then
  tf_destroy_args+=("-auto-approve")
fi

cleanup_eks_load_balancers() {
  if ! command -v kubectl >/dev/null 2>&1; then
    echo "kubectl not found; skipping Kubernetes LoadBalancer pre-cleanup."
    return
  fi

  if ! aws eks describe-cluster --region "$AWS_REGION" --name "$EKS_CLUSTER_NAME" >/dev/null 2>&1; then
    echo "EKS cluster $EKS_CLUSTER_NAME not found or not reachable; skipping Kubernetes LoadBalancer pre-cleanup."
    return
  fi

  echo "Fetching kubeconfig for EKS LoadBalancer cleanup..."
  aws eks update-kubeconfig --region "$AWS_REGION" --name "$EKS_CLUSTER_NAME" >/dev/null

  echo "Deleting Kubernetes LoadBalancer services in namespace '$WATCHMEN_NAMESPACE'..."
  mapfile -t lb_services < <(
    kubectl -n "$WATCHMEN_NAMESPACE" get svc \
      -o jsonpath='{range .items[?(@.spec.type=="LoadBalancer")]}{.metadata.name}{"\n"}{end}' \
      2>/dev/null || true
  )

  if [ "${#lb_services[@]}" -eq 0 ]; then
    echo "No Kubernetes LoadBalancer services found in namespace '$WATCHMEN_NAMESPACE'."
    return
  fi

  for svc in "${lb_services[@]}"; do
    [ -n "$svc" ] || continue
    kubectl -n "$WATCHMEN_NAMESPACE" delete svc "$svc" --ignore-not-found
  done
}

if [ "$DESTROY_EKS" = "true" ]; then
  cleanup_eks_load_balancers

  echo "Destroying stacks/aws-eks-cluster..."
  terraform -chdir="$repo_root/stacks/aws-eks-cluster" init
  terraform -chdir="$repo_root/stacks/aws-eks-cluster" destroy \
    "${tf_destroy_args[@]}" \
    -var="aws_region=$AWS_REGION" \
    -var="cluster_name=$EKS_CLUSTER_NAME"
fi

if [ "$DESTROY_TEST_ENVIRONMENT" = "true" ]; then
  echo "Destroying stacks/aws-test-environment..."
  test_env_args=(
    "--region=$AWS_REGION"
    "--name-prefix=$NAME_PREFIX"
  )
  if [ "$AUTO_APPROVE" = "true" ]; then
    test_env_args+=("--auto-approve")
  fi

  AWS_REGION="$AWS_REGION" NAME_PREFIX="$NAME_PREFIX" \
    "$repo_root/stacks/aws-test-environment/destroy.sh" "${test_env_args[@]}"
fi

echo "AWS test asset destroy flow completed."
