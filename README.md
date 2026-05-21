# Watchmen Infra Stacks

This repository contains multiple standalone Terraform stacks. Do not run
`terraform apply` from the repository root.

Use one stack directory at a time:

- `stacks/live-streaming-gcp`
- `stacks/live-streaming-aws`
- `stacks/security-fixes`
- `stacks/security-fixes-faulty`
- `watchmen-live-streaming-gcp-local-test`

Examples:

```bash
terraform -chdir=stacks/live-streaming-gcp init
terraform -chdir=stacks/live-streaming-gcp plan -var="gcp_project_id=watchmen-test-488807"
terraform -chdir=stacks/live-streaming-gcp apply -var="gcp_project_id=watchmen-test-488807"
```
