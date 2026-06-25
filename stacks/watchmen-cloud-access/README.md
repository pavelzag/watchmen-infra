# Watchmen Cloud Access

Terraform for the post-login cloud connection flow in Watchmen.

This stack creates:

- a GCP scanner service account with a JSON key for Watchmen Settings
- an AWS read-only scanner role that Watchmen assumes with an External ID
- optional minimal AWS runtime keys that can only assume the scanner role
- optional AWS access keys for the advanced/manual credentials path

Run it from this directory or with `-chdir`; do not run Terraform from the repo root.

## Deploy

Use an AWS identity that can manage IAM, such as an admin/provisioning profile.
Do not run this stack with the `watchmen-scanner` access key that the stack
creates for the app; that key is intentionally read-only.

```bash
cp terraform.tfvars.example terraform.tfvars
terraform init
terraform apply
```

Or from the infra repo root:

```bash
terraform -chdir=stacks/watchmen-cloud-access init
AWS_PROFILE=your-admin-profile terraform -chdir=stacks/watchmen-cloud-access apply
```

## Configure Watchmen

GCP:

```bash
terraform output -raw gcp_service_account_key_json
```

Paste the JSON into Watchmen:

`Settings -> Cloud Credentials -> GCP -> Service account JSON`

AWS:

For the default Watchmen AWS Access Keys form, create direct scanner keys.
By default this reuses an existing IAM user named `watchmen-scanner`:

```bash
terraform apply -var='create_aws_manual_access_key_user=true'
terraform output -raw aws_manual_access_key_id
terraform output -raw aws_manual_secret_access_key
```

If the user does not exist yet, create it too:

```bash
terraform apply \
  -var='create_aws_manual_access_key_user=true' \
  -var='create_aws_manual_user=true'
```

Paste those into Watchmen:

`Settings -> Cloud Credentials -> AWS -> Access keys`

Do not paste `aws_assumer_*` outputs into the Access keys form. Assumer keys are only for the Watchmen server runtime when using Role ARN auth.

Role ARN mode:

```bash
terraform apply -var='create_aws_role=true'
terraform output -raw aws_role_arn
terraform output -raw aws_external_id
```

Paste those values into Watchmen:

`Settings -> Cloud Credentials -> AWS -> Role ARN`

The Watchmen server must run with base AWS credentials that are allowed to call `sts:AssumeRole` on the role ARN. For local same-account testing, the trust policy defaults to the current AWS account root and still requires the External ID.

For hosted Watchmen, set `watchmen_server_principal_arns` to the IAM role/user ARN used by the server runtime before applying.

If Watchmen does not already have an AWS runtime identity, create a minimal assumer user:

```bash
terraform apply -var='create_aws_assumer_access_key_user=true'
terraform output -raw aws_assumer_access_key_id
terraform output -raw aws_assumer_secret_access_key
```

Set those as `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY` on the Watchmen server. They cannot scan directly; they can only assume the scanner role with the External ID.

## Optional Manual AWS Keys

The app defaults to AWS access keys for simple testing. To create an access key
for an existing `watchmen-scanner` IAM user:

```bash
terraform apply -var='create_aws_manual_access_key_user=true'
terraform output -raw aws_manual_access_key_id
terraform output -raw aws_manual_secret_access_key
```

If the IAM user does not exist, add `-var='create_aws_manual_user=true'`.

These secrets are stored in Terraform state. Keep the state private and rotate keys after testing.

## Destroy

```bash
terraform destroy
```

Destroying this stack deletes the GCP service account key and AWS role/user resources created here. It does not disable GCP APIs because `disable_on_destroy=false`.
