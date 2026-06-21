# Watchmen Infra Stacks

This repository contains Watchmen infrastructure assets: standalone Terraform
stacks, Kubernetes manifests, systemd units, and local vendor tooling. Do not
run `terraform apply` from the repository root.

See [DEPLOYMENTS.md](DEPLOYMENTS.md) for detailed AWS and GCP deployment
inventories, commands, inputs, outputs, and cleanup steps.

Use one stack directory at a time:

- `stacks/live-streaming-gcp`
- `stacks/live-streaming-aws`
- `stacks/aws-watchmen-user`
- `stacks/aws-eks-cluster`
- `stacks/aws-test-environment`
- `stacks/security-fixes`
- `stacks/security-fixes-faulty`
- `stacks/gcp-gke-cluster`
- `watchmen-live-streaming-gcp-local-test`

Moved from the application repo:

- `k8s/` - Kubernetes manifests for Watchmen, the processor, test app, Istio config, and the eBPF agent.
- `deploy/` - host/service deployment assets such as systemd units.
- `istio-1.21.0/` - local Istio tooling/vendor directory.
- `.terraform-originals/` - Terraform remediation originals.

Examples:

```bash
terraform -chdir=stacks/live-streaming-gcp init
terraform -chdir=stacks/live-streaming-gcp plan -var="gcp_project_id=watchmen-test-488807"
terraform -chdir=stacks/live-streaming-gcp apply -var="gcp_project_id=watchmen-test-488807"
```

## AWS Watchmen Access User

Create a read-only/security-review IAM user for connecting AWS to Watchmen:

```bash
terraform -chdir=stacks/aws-watchmen-user init
terraform -chdir=stacks/aws-watchmen-user apply
terraform -chdir=stacks/aws-watchmen-user output -raw access_key_id
terraform -chdir=stacks/aws-watchmen-user output -raw secret_access_key
```

The generated user attaches AWS managed `ReadOnlyAccess`, `SecurityAudit`, and
`IAMReadOnlyAccess`. The secret key is stored in Terraform state, so keep that
state private or set `create_access_key=false` and rotate credentials manually.

## AWS EKS Watchmen Agent Test

Create a small EKS cluster:

```bash
terraform -chdir=stacks/aws-eks-cluster init
terraform -chdir=stacks/aws-eks-cluster apply
aws eks update-kubeconfig --region us-east-1 --name watchmen-test
```

Deploy the Watchmen agent and trace-test services:

```bash
WATCHMEN_AGENT_SECRET='replace-me' scripts/deploy-watchmen-agent-eks.sh
```

Render the manifest without applying it:

```bash
WATCHMEN_AGENT_SECRET='replace-me' scripts/deploy-watchmen-agent-eks.sh --dry-run
```

## Full AWS Watchmen Test Environment

Create AWS test fixtures comparable to the current `gcp/` stack:

```bash
terraform -chdir=stacks/aws-test-environment init
terraform -chdir=stacks/aws-test-environment apply
```

This creates S3 buckets, IAM users/access keys, Lambda services behind an HTTP
API, EC2 instances, security groups, an optional RDS MySQL instance, Glue
databases, SNS topics, SQS queues, and Secrets Manager secrets.

The stack intentionally creates several risky-looking resources for Watchmen
testing, including broad security groups, public API routes, demo leaked
secrets, admin identities, and multiple IAM access keys. For a cheaper inventory
run, disable compute/database fixtures:

```bash
terraform -chdir=stacks/aws-test-environment apply -var='create_ec2=false' -var='create_rds=false'
```

## GKE test cluster with external LoadBalancer

Use the setup helper to create the GKE test cluster and the public
`watchmen-trace-main` Kubernetes `LoadBalancer`:

```bash
stacks/gcp-gke-cluster/apply.sh
```

The script uses these defaults:

- `PROJECT_ID=watchmen-test-488807`
- `REGION=us-central1`
- `CLUSTER_NAME=watchmen-test`
- `WATCHMEN_URL=https://watchmen-kappa.vercel.app`
- `WATCHMEN_NAMESPACE=watchmen`

It checks `gcloud` auth, starts login if needed, sets the active GCP project,
runs `terraform init -upgrade`, applies the stack, fetches Kubernetes
credentials, prints Terraform outputs, and shows the Kubernetes services in the
`watchmen` namespace.

Preview the Terraform plan without creating resources:

```bash
stacks/gcp-gke-cluster/apply.sh --plan-only
```

For a fresh cluster with the Watchmen eBPF agent, pass the agent secret:

```bash
stacks/gcp-gke-cluster/apply.sh \
  --with-agent \
  --agent-secret="$WATCHMEN_AGENT_SECRET"
```

Override defaults with flags or environment variables:

```bash
PROJECT_ID=my-gcp-project REGION=us-east1 stacks/gcp-gke-cluster/apply.sh

stacks/gcp-gke-cluster/apply.sh \
  --project=my-gcp-project \
  --region=us-east1 \
  --cluster-name=watchmen-test \
  --watchmen-url=https://watchmen-kappa.vercel.app
```

Equivalent raw Terraform commands, if you do not want to use the helper:

```bash
terraform -chdir=stacks/gcp-gke-cluster init
terraform -chdir=stacks/gcp-gke-cluster apply \
  -var="watchmen_url=https://watchmen-kappa.vercel.app" \
  -var="deploy_trace_test=true"
```

After apply, Terraform creates three small Go HTTP applications:

- `watchmen-trace-main` - public Kubernetes `LoadBalancer`
- `watchmen-trace-worker-a` - internal `ClusterIP`
- `watchmen-trace-worker-b` - internal `ClusterIP`

Each request to `watchmen-trace-main` calls both workers, and worker B also
calls worker A. Terraform sends test requests by default and prints
`trace_test_url` plus `trace_ui_check`. Open the Trace UI URL and look for
traffic between `watchmen-trace-main`, `watchmen-trace-worker-a`, and
`watchmen-trace-worker-b`.

For a fresh cluster with the eBPF agent, the helper passes the equivalent of:

```bash
-var="create_watchmen_namespace=true" \
-var="create_watchmen_agent_secret=true" \
-var="watchmen_agent_secret=$WATCHMEN_AGENT_SECRET" \
-var="create_watchmen_ebpf_agent=true"
```

Destroy the GKE test cluster and release Kubernetes external load balancers:

```bash
stacks/gcp-gke-cluster/destroy.sh
stacks/gcp-gke-cluster/destroy.sh --auto-approve
```

The first command shows the Terraform destroy plan. The second command first
tries to delete Kubernetes `LoadBalancer` services in the `watchmen` namespace,
then destroys the Terraform-managed GKE cluster, node pool, network, subnet,
and Kubernetes test resources. The helper defaults `REFRESH_STATE=false`
because the current Kubernetes provider/state combination fails during refresh;
override with `REFRESH_STATE=true` if you want Terraform to refresh state first.
