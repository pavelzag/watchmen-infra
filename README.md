# Watchmen Infra Stacks

This repository contains multiple standalone Terraform stacks. Do not run
`terraform apply` from the repository root.

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
- `watchmen-live-streaming-gcp-local-test`

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
