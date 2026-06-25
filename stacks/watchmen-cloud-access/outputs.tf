output "aws_role_arn" {
  description = "Paste this Role ARN into Watchmen Settings -> Cloud Credentials -> AWS -> Role ARN."
  value       = var.create_aws_role ? aws_iam_role.watchmen_scanner[0].arn : null
}

output "aws_external_id" {
  description = "Paste this External ID into Watchmen with the AWS Role ARN."
  value       = var.aws_external_id
  sensitive   = true
}

output "aws_trusted_principal_arns" {
  description = "IAM principals allowed to assume the Watchmen scanner role."
  value       = local.aws_trusted_principal_arns
}

output "aws_assumer_access_key_id" {
  description = "Optional AWS access key ID for the Watchmen server runtime. Null unless create_aws_assumer_access_key_user=true."
  value       = var.create_aws_assumer_access_key_user && var.create_aws_role ? aws_iam_access_key.watchmen_assumer[0].id : null
  sensitive   = true
}

output "aws_assumer_secret_access_key" {
  description = "Optional AWS secret access key for the Watchmen server runtime. Null unless create_aws_assumer_access_key_user=true."
  value       = var.create_aws_assumer_access_key_user && var.create_aws_role ? aws_iam_access_key.watchmen_assumer[0].secret : null
  sensitive   = true
}

output "aws_manual_access_key_id" {
  description = "Optional manual AWS access key ID. Null unless create_aws_manual_access_key_user=true."
  value       = var.create_aws_manual_access_key_user ? aws_iam_access_key.watchmen_manual[0].id : null
  sensitive   = true
}

output "aws_manual_user_name" {
  description = "IAM user configured for Watchmen's AWS Access Keys credential mode."
  value       = var.create_aws_manual_access_key_user || var.create_aws_manual_user ? local.aws_manual_user_name_resolved : null
}

output "aws_manual_secret_access_key" {
  description = "Optional manual AWS secret access key. Null unless create_aws_manual_access_key_user=true."
  value       = var.create_aws_manual_access_key_user ? aws_iam_access_key.watchmen_manual[0].secret : null
  sensitive   = true
}

output "gcp_service_account_email" {
  description = "GCP service account configured for Watchmen scanning."
  value       = google_service_account.watchmen_scanner.email
}

output "gcp_service_account_key_json" {
  description = "Paste this JSON into Watchmen Settings -> Cloud Credentials -> GCP."
  value       = base64decode(google_service_account_key.watchmen_scanner.private_key)
  sensitive   = true
}

output "gcp_service_account_key_base64" {
  description = "Base64 service account JSON for deployments that still use GCP_SERVICE_ACCOUNT_KEY."
  value       = google_service_account_key.watchmen_scanner.private_key
  sensitive   = true
}
