#!/usr/bin/env bash
# Creates the test GKE cluster and public trace-test LoadBalancer.
set -euo pipefail

cd "$(dirname "$0")"

PROJECT_ID="${PROJECT_ID:-watchmen-test-488807}"
REGION="${REGION:-us-central1}"
CLUSTER_NAME="${CLUSTER_NAME:-watchmen-test}"
WATCHMEN_URL="${WATCHMEN_URL:-https://watchmen-kappa.vercel.app}"
WATCHMEN_NAMESPACE="${WATCHMEN_NAMESPACE:-watchmen}"
DEPLOY_TRACE_TEST="${DEPLOY_TRACE_TEST:-true}"
CREATE_WATCHMEN_NAMESPACE="${CREATE_WATCHMEN_NAMESPACE:-true}"
WITH_AGENT="${WITH_AGENT:-false}"
WATCHMEN_AGENT_SECRET="${WATCHMEN_AGENT_SECRET:-}"
AUTO_APPROVE="${AUTO_APPROVE:-true}"
INIT_UPGRADE="${INIT_UPGRADE:-true}"
LOGIN_IF_NEEDED="${LOGIN_IF_NEEDED:-true}"

usage() {
  cat <<EOF
Usage: $0 [options]

Options:
  --project=ID             GCP project ID. Default: $PROJECT_ID
  --region=REGION         GCP region. Default: $REGION
  --cluster-name=NAME     GKE cluster name. Default: $CLUSTER_NAME
  --watchmen-url=URL      Watchmen server URL. Default: $WATCHMEN_URL
  --namespace=NAME        Kubernetes namespace. Default: $WATCHMEN_NAMESPACE
  --with-agent            Also create watchmen-agent-secret and eBPF DaemonSet.
  --agent-secret=SECRET   Secret for --with-agent. Can also use WATCHMEN_AGENT_SECRET.
  --plan-only             Run terraform plan instead of apply.
  --no-init-upgrade       Run terraform init without -upgrade.
  --no-login              Do not run gcloud auth login commands if auth is missing.
  -h, --help              Show this help.

Environment overrides:
  PROJECT_ID, REGION, CLUSTER_NAME, WATCHMEN_URL, WATCHMEN_NAMESPACE
  DEPLOY_TRACE_TEST, CREATE_WATCHMEN_NAMESPACE, WITH_AGENT
  WATCHMEN_AGENT_SECRET, AUTO_APPROVE, INIT_UPGRADE
  LOGIN_IF_NEEDED
EOF
}

for arg in "$@"; do
  case "$arg" in
    --project=*)
      PROJECT_ID="${arg#*=}"
      ;;
    --region=*)
      REGION="${arg#*=}"
      ;;
    --cluster-name=*)
      CLUSTER_NAME="${arg#*=}"
      ;;
    --watchmen-url=*)
      WATCHMEN_URL="${arg#*=}"
      ;;
    --namespace=*)
      WATCHMEN_NAMESPACE="${arg#*=}"
      ;;
    --with-agent)
      WITH_AGENT="true"
      ;;
    --agent-secret=*)
      WATCHMEN_AGENT_SECRET="${arg#*=}"
      ;;
    --plan-only)
      AUTO_APPROVE="false"
      ;;
    --no-init-upgrade)
      INIT_UPGRADE="false"
      ;;
    --no-login)
      LOGIN_IF_NEEDED="false"
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
require_command gcloud

if [ "$WITH_AGENT" = "true" ] && [ -z "$WATCHMEN_AGENT_SECRET" ]; then
  echo "WATCHMEN_AGENT_SECRET is required when --with-agent is used." >&2
  exit 1
fi

echo "Checking gcloud authentication..."
if ! gcloud auth list --filter=status:ACTIVE --format='value(account)' | grep -q .; then
  if [ "$LOGIN_IF_NEEDED" = "true" ]; then
    echo "No active gcloud account. Starting browser login..."
    gcloud auth login
  fi
fi

if ! gcloud auth list --filter=status:ACTIVE --format='value(account)' | grep -q .; then
  echo "No active gcloud account. Run: gcloud auth login" >&2
  exit 1
fi

if ! gcloud auth application-default print-access-token >/dev/null 2>&1; then
  if [ "$LOGIN_IF_NEEDED" = "true" ]; then
    echo "Application Default Credentials are missing. Starting ADC login..."
    gcloud auth application-default login
  fi
fi

if ! gcloud auth application-default print-access-token >/dev/null 2>&1; then
  echo "Application Default Credentials are not available." >&2
  echo "Run: gcloud auth application-default login" >&2
  exit 1
fi

echo "Setting active gcloud project to $PROJECT_ID..."
gcloud config set project "$PROJECT_ID" >/dev/null

terraform_args=(
  -var="project_id=$PROJECT_ID"
  -var="region=$REGION"
  -var="cluster_name=$CLUSTER_NAME"
  -var="watchmen_url=$WATCHMEN_URL"
  -var="watchmen_namespace=$WATCHMEN_NAMESPACE"
  -var="deploy_trace_test=$DEPLOY_TRACE_TEST"
  -var="create_watchmen_namespace=$CREATE_WATCHMEN_NAMESPACE"
)

if [ "$WITH_AGENT" = "true" ]; then
  terraform_args+=(
    -var="create_watchmen_agent_secret=true"
    -var="watchmen_agent_secret=$WATCHMEN_AGENT_SECRET"
    -var="create_watchmen_ebpf_agent=true"
  )
fi

echo "Initialising Terraform..."
if [ "$INIT_UPGRADE" = "true" ]; then
  terraform init -upgrade
else
  terraform init
fi

if [ "$AUTO_APPROVE" = "true" ]; then
  echo "Applying GKE stack..."
  terraform apply -auto-approve "${terraform_args[@]}"
else
  echo "Planning GKE stack..."
  terraform plan "${terraform_args[@]}"
  exit 0
fi

echo ""
echo "Fetching Kubernetes credentials..."
gcloud container clusters get-credentials "$CLUSTER_NAME" --region "$REGION" --project "$PROJECT_ID"

echo ""
echo "Terraform outputs:"
terraform output

if command -v kubectl >/dev/null 2>&1; then
  echo ""
  echo "Kubernetes services in namespace '$WATCHMEN_NAMESPACE':"
  kubectl -n "$WATCHMEN_NAMESPACE" get svc || true
else
  echo ""
  echo "kubectl is not installed; skipping Kubernetes service status."
fi
