#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  WATCHMEN_AGENT_SECRET=... scripts/deploy-watchmen-agent-eks.sh [options]

Deploys the Watchmen eBPF agent DaemonSet and trace-test services to the
current kubectl context, defaulting values from the aws-eks-cluster Terraform
stack when possible.

Options:
  --namespace NAME             Kubernetes namespace. Default: watchmen
  --watchmen-url URL           Watchmen base URL. Default: https://watchmen-kappa.vercel.app
  --agent-secret SECRET        Watchmen agent shared secret. Can also use WATCHMEN_AGENT_SECRET.
  --agent-binary-url URL       Agent binary URL.
  --agent-version VERSION      Agent version label. Default: agent-v0.3.19
  --cluster NAME               EKS cluster name. Default: Terraform output cluster_name or watchmen-test.
  --region REGION              AWS region. Default: AWS_REGION or us-east-1.
  --account-id ID              AWS account ID. Default: aws sts get-caller-identity.
  --trace-test-image IMAGE     Go image used to build trace-test app. Default: golang:1.22-alpine
  --verbose 0|1                Set WATCHMEN_VERBOSE. Default: 1
  --dry-run                    Render YAML to stdout without applying it.
  -h, --help                   Show this help.

Examples:
  terraform -chdir=stacks/aws-eks-cluster apply
  aws eks update-kubeconfig --region us-east-1 --name watchmen-test
  WATCHMEN_AGENT_SECRET='...' scripts/deploy-watchmen-agent-eks.sh
EOF
}

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tf_dir="$repo_root/stacks/aws-eks-cluster"
manifest="$repo_root/k8s/eks-watchmen-agent.yaml"

WATCHMEN_NAMESPACE="${WATCHMEN_NAMESPACE:-watchmen}"
WATCHMEN_URL="${WATCHMEN_URL:-https://watchmen-kappa.vercel.app}"
WATCHMEN_AGENT_SECRET="${WATCHMEN_AGENT_SECRET:-}"
WATCHMEN_AGENT_BINARY_URL="${WATCHMEN_AGENT_BINARY_URL:-https://github.com/pavelzag/watchmen/releases/download/agent-v0.3.19/watchmen-ebpf-agent-linux-amd64}"
WATCHMEN_AGENT_VERSION="${WATCHMEN_AGENT_VERSION:-agent-v0.3.19}"
EKS_CLUSTER_NAME="${EKS_CLUSTER_NAME:-}"
AWS_REGION="${AWS_REGION:-us-east-1}"
AWS_ACCOUNT_ID="${AWS_ACCOUNT_ID:-}"
TRACE_TEST_IMAGE="${TRACE_TEST_IMAGE:-golang:1.22-alpine}"
WATCHMEN_VERBOSE="${WATCHMEN_VERBOSE:-1}"
dry_run=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --namespace)
      WATCHMEN_NAMESPACE="${2:-}"
      shift 2
      ;;
    --watchmen-url)
      WATCHMEN_URL="${2:-}"
      shift 2
      ;;
    --agent-secret)
      WATCHMEN_AGENT_SECRET="${2:-}"
      shift 2
      ;;
    --agent-binary-url)
      WATCHMEN_AGENT_BINARY_URL="${2:-}"
      shift 2
      ;;
    --agent-version)
      WATCHMEN_AGENT_VERSION="${2:-}"
      shift 2
      ;;
    --cluster)
      EKS_CLUSTER_NAME="${2:-}"
      shift 2
      ;;
    --region)
      AWS_REGION="${2:-}"
      shift 2
      ;;
    --account-id)
      AWS_ACCOUNT_ID="${2:-}"
      shift 2
      ;;
    --trace-test-image)
      TRACE_TEST_IMAGE="${2:-}"
      shift 2
      ;;
    --verbose)
      WATCHMEN_VERBOSE="${2:-}"
      shift 2
      ;;
    --dry-run)
      dry_run=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [[ -z "$WATCHMEN_AGENT_SECRET" ]]; then
  echo "WATCHMEN_AGENT_SECRET is required." >&2
  usage >&2
  exit 2
fi

if [[ -z "$EKS_CLUSTER_NAME" && -d "$tf_dir" ]]; then
  maybe_cluster_name="$(terraform -chdir="$tf_dir" output -raw -no-color cluster_name 2>/dev/null || true)"
  if [[ "$maybe_cluster_name" =~ ^[A-Za-z0-9._-]+$ ]]; then
    EKS_CLUSTER_NAME="$maybe_cluster_name"
  fi
fi
EKS_CLUSTER_NAME="${EKS_CLUSTER_NAME:-watchmen-test}"

if [[ -z "$AWS_ACCOUNT_ID" ]] && command -v aws >/dev/null 2>&1; then
  AWS_ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text 2>/dev/null || true)"
fi
AWS_ACCOUNT_ID="${AWS_ACCOUNT_ID:-unknown}"

WATCHMEN_URL="${WATCHMEN_URL%/}"
WATCHMEN_API_URL="${WATCHMEN_URL}/api"

export WATCHMEN_NAMESPACE
export WATCHMEN_AGENT_SECRET
export WATCHMEN_AGENT_BINARY_URL
export WATCHMEN_AGENT_VERSION
export WATCHMEN_API_URL
export EKS_CLUSTER_NAME
export AWS_REGION
export AWS_ACCOUNT_ID
export TRACE_TEST_IMAGE
export WATCHMEN_VERBOSE

render_manifest() {
  envsubst '${WATCHMEN_NAMESPACE} ${WATCHMEN_AGENT_SECRET} ${WATCHMEN_AGENT_BINARY_URL} ${WATCHMEN_AGENT_VERSION} ${WATCHMEN_API_URL} ${EKS_CLUSTER_NAME} ${AWS_REGION} ${AWS_ACCOUNT_ID} ${TRACE_TEST_IMAGE} ${WATCHMEN_VERBOSE}' < "$manifest"
}

if [[ "$dry_run" -eq 1 ]]; then
  render_manifest
  exit 0
fi

render_manifest | kubectl apply -f -

cat <<EOF

Deployed Watchmen agent and trace-test services to namespace: $WATCHMEN_NAMESPACE

Check rollout:
  kubectl -n $WATCHMEN_NAMESPACE rollout status daemonset/watchmen-ebpf-agent
  kubectl -n $WATCHMEN_NAMESPACE get pods,svc

Get trace-test URL after the LoadBalancer is ready:
  kubectl -n $WATCHMEN_NAMESPACE get svc watchmen-trace-main
EOF
