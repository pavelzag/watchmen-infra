#!/usr/bin/env bash
# Destroys the test GKE cluster and Terraform-managed Kubernetes resources.
set -euo pipefail

cd "$(dirname "$0")"

PROJECT_ID="${PROJECT_ID:-watchmen-test-488807}"
REGION="${REGION:-us-central1}"
CLUSTER_NAME="${CLUSTER_NAME:-watchmen-test}"
WATCHMEN_URL="${WATCHMEN_URL:-https://watchmen-kappa.vercel.app}"
WATCHMEN_NAMESPACE="${WATCHMEN_NAMESPACE:-watchmen}"
REFRESH_STATE="${REFRESH_STATE:-false}"
AUTO_APPROVE=0
SKIP_K8S_LOAD_BALANCER_CLEANUP=0

usage() {
  cat <<EOF
Usage: $0 [--auto-approve] [--skip-k8s-load-balancer-cleanup]

Environment overrides:
  PROJECT_ID=$PROJECT_ID
  REGION=$REGION
  CLUSTER_NAME=$CLUSTER_NAME
  WATCHMEN_URL=$WATCHMEN_URL
  WATCHMEN_NAMESPACE=$WATCHMEN_NAMESPACE
  REFRESH_STATE=$REFRESH_STATE

By default this runs a destroy plan. Pass --auto-approve to actually destroy.
Before Terraform destroy, the script tries to delete Kubernetes LoadBalancer
services in WATCHMEN_NAMESPACE so their external cloud load balancers are
released before the cluster is removed.
REFRESH_STATE defaults to false to avoid Kubernetes provider identity refresh
errors with the current local state.
EOF
}

for arg in "$@"; do
  case "$arg" in
    --auto-approve)
      AUTO_APPROVE=1
      ;;
    --skip-k8s-load-balancer-cleanup)
      SKIP_K8S_LOAD_BALANCER_CLEANUP=1
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

terraform_args=(
  -var="project_id=$PROJECT_ID"
  -var="region=$REGION"
  -var="cluster_name=$CLUSTER_NAME"
  -var="watchmen_url=$WATCHMEN_URL"
)

if [ "$AUTO_APPROVE" -eq 1 ] && [ "$SKIP_K8S_LOAD_BALANCER_CLEANUP" -eq 0 ] && command -v gcloud >/dev/null 2>&1 && command -v kubectl >/dev/null 2>&1; then
  echo "Fetching GKE credentials for pre-destroy LoadBalancer cleanup..."
  if gcloud container clusters get-credentials "$CLUSTER_NAME" --region "$REGION" --project "$PROJECT_ID" >/dev/null 2>&1; then
    echo "Deleting Kubernetes LoadBalancer services in namespace '$WATCHMEN_NAMESPACE'..."
    load_balancer_services="$(
      kubectl get service -n "$WATCHMEN_NAMESPACE" \
        -o jsonpath='{range .items[?(@.spec.type=="LoadBalancer")]}{.metadata.name}{"\n"}{end}' \
        2>/dev/null || true
    )"

    if [ -n "$load_balancer_services" ]; then
      while IFS= read -r service_name; do
        [ -z "$service_name" ] && continue
        kubectl delete service "$service_name" -n "$WATCHMEN_NAMESPACE" --ignore-not-found
      done <<<"$load_balancer_services"
    else
      echo "No Kubernetes LoadBalancer services found in namespace '$WATCHMEN_NAMESPACE'."
    fi
  else
    echo "Could not fetch GKE credentials; continuing with Terraform destroy."
  fi
else
  echo "Skipping Kubernetes LoadBalancer pre-cleanup."
fi

if [ "$AUTO_APPROVE" -eq 1 ]; then
  echo "Destroying GKE stack..."
  terraform destroy -auto-approve -refresh="$REFRESH_STATE" "${terraform_args[@]}"
else
  echo "Planning GKE stack destroy. Re-run with --auto-approve to destroy."
  terraform plan -destroy -refresh="$REFRESH_STATE" "${terraform_args[@]}"
fi
