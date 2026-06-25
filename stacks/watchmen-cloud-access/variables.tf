variable "aws_region" {
  description = "AWS region used by the provider. IAM is global, but AWS still requires a provider region."
  type        = string
  default     = "us-east-1"
}

variable "aws_role_name" {
  description = "IAM role name that Watchmen will assume for AWS scanning."
  type        = string
  default     = "watchmen-scanner-role"
}

variable "create_aws_role" {
  description = "Create the AWS AssumeRole scanner role. Enable only when using Watchmen's Role ARN AWS connection mode."
  type        = bool
  default     = false
}

variable "aws_external_id" {
  description = "External ID required by the Watchmen scanner role trust policy. Paste this value into Watchmen with the role ARN."
  type        = string
  default     = "watchmen-local-test"
  sensitive   = true
}

variable "watchmen_server_principal_arns" {
  description = "IAM principal ARNs allowed to assume the Watchmen scanner role. Leave empty for local same-account testing; Terraform will trust the current AWS account root."
  type        = list(string)
  default     = []
}

variable "aws_extra_policy_arns" {
  description = "Additional AWS managed policy ARNs to attach to the Watchmen scanner role."
  type        = list(string)
  default     = []
}

variable "create_aws_manual_access_key_user" {
  description = "Create an IAM access key for Watchmen's AWS Access Keys credential mode."
  type        = bool
  default     = false
}

variable "create_aws_manual_user" {
  description = "Create the IAM user used for Watchmen's AWS Access Keys credential mode. Leave false to reuse an existing user named by aws_manual_user_name."
  type        = bool
  default     = false
}

variable "create_aws_assumer_access_key_user" {
  description = "Create a minimal IAM user/access key for the Watchmen server runtime. This user can only call sts:AssumeRole on the scanner role."
  type        = bool
  default     = false
}

variable "aws_assumer_user_name" {
  description = "IAM user name for optional Watchmen server runtime credentials used with Role ARN auth."
  type        = string
  default     = "watchmen-role-assumer"
}

variable "aws_manual_user_name" {
  description = "IAM user name for optional manual AWS access keys."
  type        = string
  default     = "watchmen-scanner"
}

variable "gcp_project_id" {
  description = "GCP project ID to configure for Watchmen scanning."
  type        = string
}

variable "gcp_region" {
  description = "Default GCP region used by the provider."
  type        = string
  default     = "us-central1"
}

variable "gcp_service_account_id" {
  description = "GCP service account ID for Watchmen scanning."
  type        = string
  default     = "watchmen-scanner"
}

variable "gcp_enable_services" {
  description = "Enable GCP APIs commonly scanned by Watchmen."
  type        = bool
  default     = true
}

variable "gcp_extra_project_roles" {
  description = "Additional GCP project roles to grant to the Watchmen scanner service account."
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Common AWS tags applied to created resources."
  type        = map(string)
  default = {
    managed_by = "terraform"
    app        = "watchmen"
    purpose    = "cloud-scanner-access"
  }
}
