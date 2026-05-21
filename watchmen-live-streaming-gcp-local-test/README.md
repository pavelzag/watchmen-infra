# Watchmen GCP Trace Streaming: Local Test Bundle

This bundle provisions the GCP side of Watchmen live trace streaming for a **local** Watchmen instance.

It is intended for testing with a public tunnel such as `ngrok` or `cloudflared`.

## What this creates

- Cloud Logging sink: `watchmen-live-trace-sink`
- Pub/Sub topic: `watchmen-live-trace-topic`
- Pub/Sub push subscription: `watchmen-live-trace-subscription`
- Service account used by Pub/Sub to mint OIDC tokens for push delivery

## Why a tunnel is required

Google Pub/Sub push delivery must call a public HTTPS URL.

Your local Watchmen dev server at `http://localhost:3019` is not reachable from Google Cloud, so you need a temporary tunnel that forwards a public HTTPS URL to:

`http://localhost:3019/api/ingest/gcp/pubsub`

## Suggested local flow

1. Start Watchmen locally:

```bash
npm run dev
```

2. Start a tunnel to port `3019`.

Example with ngrok:

```bash
ngrok http 3019
```

Example with cloudflared:

```bash
cloudflared tunnel --url http://localhost:3019
```

3. Copy the public HTTPS tunnel URL and append:

`/api/ingest/gcp/pubsub`

Example:

`https://abc123.ngrok-free.app/api/ingest/gcp/pubsub`

4. Copy `terraform.tfvars.example` to `terraform.tfvars` and update:

- `gcp_project_id`
- `watchmen_push_url`
- `watchmen_push_audience`

5. Apply Terraform:

```bash
terraform init
terraform plan
terraform apply
```

6. In Watchmen Settings, set GCP Trace Source to `Streaming` and use:

- the same `gcp_project_id`
- the same public tunnel URL as `Push Endpoint`

7. Generate traffic in the target GCP project and watch the Trace view.

## Important notes

- If the tunnel URL changes, update `watchmen_push_url` and re-apply Terraform.
- This setup is for local testing only. Do not treat a temporary tunnel as production infrastructure.
- The current Watchmen app path consumes **Pub/Sub push**, not pull subscriptions.
- OIDC verification on the Watchmen ingestion route should be enabled before production deployment.

## Cleanup

To remove the streaming resources:

```bash
terraform destroy
```
