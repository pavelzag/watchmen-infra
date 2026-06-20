# Watchmen Deployment Details

This repo contains standalone Terraform stacks and Kubernetes/scripts for testing
Watchmen on GCP and AWS. Do not run `terraform apply` from the repository root.
Use one stack directory at a time.

## Prerequisites

- Terraform `>= 1.5`
- `gcloud` authenticated for GCP stacks
- `aws` authenticated for AWS stacks
- `kubectl` for GKE/EKS agent deployment
- `envsubst` for `scripts/deploy-watchmen-agent-eks.sh`

## Deployment Matrix

| Target | Path | Purpose |
| --- | --- | --- |
| GCP full test environment | `gcp/` | Broad GCP inventory, identity, storage, compute, serverless, data, and secret fixtures |
| GCP live trace streaming | `stacks/live-streaming-gcp/` | Cloud Logging to Pub/Sub for Watchmen trace ingestion |
| GCP local trace streaming | `watchmen-live-streaming-gcp-local-test/` | Pub/Sub push to a local Watchmen instance through a public tunnel |
| GCP GKE agent test | `stacks/gcp-gke-cluster/` | Minimal GKE cluster, Watchmen agent resources, and trace-test services |
| AWS Watchmen access user | `stacks/aws-watchmen-user/` | Minimal IAM user for connecting AWS to Watchmen |
| AWS full test environment | `stacks/aws-test-environment/` | Broad AWS equivalent of the GCP test fixtures |
| AWS live trace streaming | `stacks/live-streaming-aws/` | CloudWatch Logs subscription filters to Kinesis |
| AWS EKS agent test | `stacks/aws-eks-cluster/` + `scripts/deploy-watchmen-agent-eks.sh` | Minimal EKS cluster and Watchmen agent deployment |

## GCP Full Test Environment

Path: `gcp/`

### What It Creates

- Service accounts:
  - `wm-test-etl`
  - `wm-test-reporting`
  - `wm-test-cicd`
  - `wm-attack-escalation-sa`
  - `wm-attack-owner-sa`
  - `wm-attack-multikey-sa`
  - `wm-attack-exposed-cicd`
  - `github-ci`
  - `watchmen-reader`
- IAM bindings for normal reader/reporting access and intentionally risky test cases.
- Service account keys for multi-key and exposed CI/CD scenarios.
- Storage buckets:
  - logs
  - data
  - backups
  - attack public data
  - attack public uploads
  - Cloud Build bucket
- Cloud Run services:
  - normal hello/API services
  - leaked AWS credentials demo
  - Stripe key demo
  - GitHub token demo
  - DB password env var demo
  - public internal API demo
  - public API with high-privilege service account demo
- Compute firewall rules:
  - internal traffic
  - SSH/RDP rules
  - open HTTP/HTTPS
  - open DB ports
  - allow-all ingress test rule
- Compute resources:
  - GKE cluster `wm-test-cluster`
  - GKE node pool `wm-test-node-pool`
  - normal VM
  - privileged VM
  - exposed VM
  - dev instance
- Data services:
  - Cloud SQL MySQL instance
  - BigQuery datasets
  - Pub/Sub topics
  - Secret Manager secrets

### Commands

```bash
cd gcp
./apply.sh --project=watchmen-test-488807
```

Equivalent direct Terraform flow:

```bash
terraform -chdir=gcp init
terraform -chdir=gcp apply -var='project_id=watchmen-test-488807'
```

Destroy:

```bash
cd gcp
./destroy.sh --project=watchmen-test-488807
```

### Important Inputs

- `project_id`: GCP project ID. Default: `watchmen-test-488807`
- `region`: default `us-central1`
- `zone`: default `us-central1-a`
- `project_owner_email`: default `zagalsky@gmail.com`

### Useful Outputs

- `service_accounts`
- `buckets`
- `cloud_run_services`
- `compute_instances`
- `pubsub_topics`
- `secret_names`

## GCP Live Trace Streaming

Path: `stacks/live-streaming-gcp/`

### What It Creates

- Enables Pub/Sub, Logging, and IAM APIs.
- Pub/Sub topic: `${name_prefix}-topic`
- Cloud Logging sink: `${name_prefix}-sink`
- IAM binding allowing the sink writer identity to publish to the topic.
- Pub/Sub subscription: `${name_prefix}-subscription`
- Optional Pub/Sub push service account and OIDC setup when `gcp_push_endpoint` is set.

### Commands

Pull subscription:

```bash
terraform -chdir=stacks/live-streaming-gcp init
terraform -chdir=stacks/live-streaming-gcp apply \
  -var='gcp_project_id=watchmen-test-488807'
```

Push subscription:

```bash
terraform -chdir=stacks/live-streaming-gcp apply \
  -var='gcp_project_id=watchmen-test-488807' \
  -var='gcp_push_endpoint=https://example.com/api/ingest/gcp/pubsub'
```

Destroy:

```bash
terraform -chdir=stacks/live-streaming-gcp destroy \
  -var='gcp_project_id=watchmen-test-488807'
```

### Important Inputs

- `gcp_project_id`: required
- `gcp_region`: default `us-central1`
- `gcp_log_filter`: defaults to Cloud Run, GCE, Kubernetes containers, and HTTP load balancers
- `gcp_push_endpoint`: optional HTTPS Pub/Sub push endpoint
- `gcp_push_audience`: optional OIDC audience

### Useful Outputs

- `gcp_pubsub_topic_name`
- `gcp_pubsub_subscription_name`
- `gcp_logging_sink_writer_identity`

## GCP Local Trace Streaming

Path: `watchmen-live-streaming-gcp-local-test/`

### What It Creates

- Cloud Logging sink: `watchmen-live-trace-sink`
- Pub/Sub topic: `watchmen-live-trace-topic`
- Pub/Sub push subscription: `watchmen-live-trace-subscription`
- Service account used by Pub/Sub to mint OIDC tokens for push delivery

### Commands

Start Watchmen locally, then expose it through a public HTTPS tunnel:

```bash
npm run dev
ngrok http 3019
```

Set `watchmen_push_url` to:

```text
https://<tunnel-host>/api/ingest/gcp/pubsub
```

Then deploy:

```bash
cd watchmen-live-streaming-gcp-local-test
cp terraform.tfvars.example terraform.tfvars
terraform init
terraform apply
```

Destroy:

```bash
terraform destroy
```

## GCP GKE Agent Test

Path: `stacks/gcp-gke-cluster/`

### What It Creates

- Minimal GKE cluster for Watchmen eBPF agent testing.
- Dedicated VPC and subnet with secondary ranges for Pods and Services.
- GKE node pool.
- Optional Watchmen namespace.
- Optional Watchmen agent secret.
- Optional Tailscale auth secret.
- Optional trace-test Go app ConfigMap.
- Three trace-test Kubernetes services/deployments:
  - `watchmen-trace-main`
  - `watchmen-trace-worker-a`
  - `watchmen-trace-worker-b`
- Optional `watchmen-ebpf-agent` DaemonSet.
- Optional generated trace-test HTTP requests.

### Commands

```bash
terraform -chdir=stacks/gcp-gke-cluster init
terraform -chdir=stacks/gcp-gke-cluster apply \
  -var='project_id=watchmen-test-488807' \
  -var='watchmen_agent_secret=replace-me'
```

Get cluster credentials:

```bash
gcloud container clusters get-credentials watchmen-test --region us-central1
```

Poll endpoints:

```bash
scripts/poll-gke-endpoints.sh \
  --email you@example.com \
  --intervals 1,2,5,10,15,20
```

Destroy:

```bash
terraform -chdir=stacks/gcp-gke-cluster destroy \
  -var='project_id=watchmen-test-488807'
```

## AWS Watchmen Access User

Path: `stacks/aws-watchmen-user/`

### What It Creates

- IAM user: `watchmen-reader`
- Attached AWS managed policies:
  - `ReadOnlyAccess`
  - `SecurityAudit`
  - `IAMReadOnlyAccess`
- Optional IAM access key for the user.

This is the minimal AWS identity for connecting an AWS account to Watchmen.

### Commands

```bash
terraform -chdir=stacks/aws-watchmen-user init
terraform -chdir=stacks/aws-watchmen-user apply
terraform -chdir=stacks/aws-watchmen-user output -raw access_key_id
terraform -chdir=stacks/aws-watchmen-user output -raw secret_access_key
```

Destroy:

```bash
terraform -chdir=stacks/aws-watchmen-user destroy
```

### Important Inputs

- `aws_region`: default `us-east-1`
- `user_name`: default `watchmen-reader`
- `create_access_key`: default `true`
- `extra_policy_arns`: optional additional IAM policy ARNs

## AWS Full Test Environment

Path: `stacks/aws-test-environment/`

### What It Creates

- S3 buckets:
  - logs
  - data
  - backups
  - attack public data
  - attack public uploads
- S3 versioning, encryption, lifecycle on logs, and public-access settings.
- IAM users:
  - ETL
  - reporting
  - CI/CD
  - GitHub CI
  - Watchmen reader
  - attack escalation
  - attack owner
  - attack multi-key
  - attack exposed CI/CD
- IAM access keys, including extra keys for multi-key scenarios.
- IAM policy attachments:
  - Watchmen reader with read/security audit permissions
  - reporting read-only
  - CI/CD power user
  - admin access for escalation/owner/exposed CI/CD test identities
  - ETL object access to logs/data buckets
- Lambda functions matching the GCP Cloud Run test services:
  - normal hello/API
  - leaked AWS credentials demo
  - Stripe key demo
  - GitHub token demo
  - DB password env var demo
  - public internal API demo
  - public API with high-privilege execution role demo
- CloudWatch log groups for Lambda.
- HTTP API Gateway with routes to all Lambda functions.
- VPC, internet gateway, public subnets, route table.
- Security groups:
  - default-like internal access
  - open SSH
  - open RDP
  - open DB ports
  - allow-all ingress
- Optional EC2 instances:
  - normal VM
  - privileged VM with admin instance profile
  - exposed VM
  - dev instance
- Optional RDS MySQL instance.
- Glue catalog databases as BigQuery-style fixtures.
- SNS topics and SQS queues as Pub/Sub-style fixtures.
- Secrets Manager secrets:
  - `wm-test-api-key`
  - `wm-test-db-password`
  - `wm-test-jwt-secret`

### Commands

Full environment:

```bash
terraform -chdir=stacks/aws-test-environment init
terraform -chdir=stacks/aws-test-environment apply
```

Cheaper inventory-only run without EC2/RDS:

```bash
terraform -chdir=stacks/aws-test-environment apply \
  -var='create_ec2=false' \
  -var='create_rds=false'
```

Destroy:

```bash
terraform -chdir=stacks/aws-test-environment destroy
```

### Important Inputs

- `aws_region`: default `us-east-1`
- `name_prefix`: default `wm-test`
- `create_access_keys`: default `true`
- `create_rds`: default `true`
- `create_ec2`: default `true`

### Useful Outputs

- `account_id`
- `iam_users`
- `watchmen_reader_access_key_id`
- `watchmen_reader_secret_access_key`
- `buckets`
- `lambda_functions`
- `http_api_base_url`
- `ec2_instances`
- `rds_instance`
- `glue_databases`
- `sns_topics`
- `sqs_queues`
- `secret_names`

## AWS Live Trace Streaming

Path: `stacks/live-streaming-aws/`

### What It Creates

- Kinesis stream: `${name_prefix}-stream`
- IAM role assumed by CloudWatch Logs.
- IAM policy allowing CloudWatch Logs to write to the Kinesis stream.
- CloudWatch log subscription filters for each log group in `aws_log_group_names`.

This covers CloudWatch Logs-backed sources such as Lambda, API Gateway logs,
ECS/EKS application logs, and EC2-shipped logs. ALB access logs are not included
because they are typically delivered to S3.

### Commands

```bash
terraform -chdir=stacks/live-streaming-aws init
terraform -chdir=stacks/live-streaming-aws apply \
  -var='aws_region=us-east-1' \
  -var='aws_log_group_names=["/aws/lambda/wm-test-hello","/aws/lambda/wm-test-api"]'
```

Destroy:

```bash
terraform -chdir=stacks/live-streaming-aws destroy \
  -var='aws_region=us-east-1' \
  -var='aws_log_group_names=["/aws/lambda/wm-test-hello","/aws/lambda/wm-test-api"]'
```

### Important Inputs

- `aws_region`: default `us-east-1`
- `aws_log_group_names`: required list of existing CloudWatch log group names
- `aws_kinesis_shard_count`: default `1`
- `aws_subscription_filter_pattern`: default empty, meaning forward all events

### Useful Outputs

- `aws_kinesis_stream_name`
- `aws_kinesis_stream_arn`
- `aws_cloudwatch_subscription_role_arn`

## AWS EKS Agent Test

Paths:

- `stacks/aws-eks-cluster/`
- `k8s/eks-watchmen-agent.yaml`
- `scripts/deploy-watchmen-agent-eks.sh`

### What The Terraform Stack Creates

- EKS cluster: `watchmen-test`
- Dedicated VPC.
- Public subnets.
- Internet gateway.
- Public route table.
- EKS cluster IAM role.
- Cluster security group.
- Managed node group.
- Node IAM role with EKS worker, CNI, and ECR read-only policies.

### What The Deployment Script Creates

- Kubernetes namespace: `watchmen`
- Secret: `watchmen-agent-secret`
- ConfigMap containing the trace-test Go app.
- Deployments:
  - `watchmen-trace-main`
  - `watchmen-trace-worker-a`
  - `watchmen-trace-worker-b`
- Services:
  - public `LoadBalancer` for `watchmen-trace-main`
  - internal `ClusterIP` services for both workers
- DaemonSet:
  - `watchmen-ebpf-agent`

### Commands

Create EKS:

```bash
terraform -chdir=stacks/aws-eks-cluster init
terraform -chdir=stacks/aws-eks-cluster apply
```

Configure `kubectl`:

```bash
aws eks update-kubeconfig --region us-east-1 --name watchmen-test
```

Deploy agent and trace-test services:

```bash
WATCHMEN_AGENT_SECRET='replace-me' scripts/deploy-watchmen-agent-eks.sh
```

Render manifest without applying:

```bash
WATCHMEN_AGENT_SECRET='replace-me' scripts/deploy-watchmen-agent-eks.sh --dry-run
```

Check rollout:

```bash
kubectl -n watchmen rollout status daemonset/watchmen-ebpf-agent
kubectl -n watchmen get pods,svc
```

Destroy Kubernetes objects:

```bash
kubectl delete -f <(WATCHMEN_AGENT_SECRET='replace-me' scripts/deploy-watchmen-agent-eks.sh --dry-run)
```

Destroy EKS:

```bash
terraform -chdir=stacks/aws-eks-cluster destroy
```

### Important Inputs

Terraform:

- `aws_region`: default `us-east-1`
- `cluster_name`: default `watchmen-test`
- `k8s_version`: default `null`, so AWS uses its current default supported version
- `node_instance_types`: default `["t3.medium"]`
- `node_desired_size`: default `2`
- `node_min_size`: default `1`
- `node_max_size`: default `3`

Deployment script:

- `WATCHMEN_AGENT_SECRET`: required
- `WATCHMEN_URL`: default `https://watchmen-kappa.vercel.app`
- `WATCHMEN_AGENT_BINARY_URL`: default agent release URL
- `WATCHMEN_AGENT_VERSION`: default `agent-v0.3.19`
- `EKS_CLUSTER_NAME`: default from Terraform output or `watchmen-test`
- `AWS_REGION`: default `us-east-1`
- `AWS_ACCOUNT_ID`: default from `aws sts get-caller-identity`
- `WATCHMEN_NAMESPACE`: default `watchmen`

## Verification Notes

Local checks run while preparing these deployment files:

- `terraform fmt -check` passed for the AWS Terraform stacks.
- `bash -n scripts/deploy-watchmen-agent-eks.sh` passed.
- `scripts/deploy-watchmen-agent-eks.sh --dry-run` rendered valid YAML.

Provider-backed validation for AWS was not completed in this environment because
downloading `hashicorp/aws v5.100.0` from the Terraform registry stalled. Run
`terraform init` and `terraform validate` locally before applying in an AWS
account.

## Cost And Safety Notes

- The full GCP and AWS test environments intentionally create risky-looking
  resources so Watchmen can detect and display them.
- Demo secrets in these stacks are fake but intentionally shaped like real
  secrets.
- Terraform state can contain access keys and secret values. Store state
  securely.
- RDS, EKS, GKE, Cloud SQL, EC2, NAT/load balancers, and public IP resources can
  incur ongoing costs.
- Always destroy test environments when finished.

