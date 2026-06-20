# AWS IAM user for Watchmen app access.
#
# This creates a dedicated IAM user with read-only/security-review permissions
# suitable for connecting an AWS account to Watchmen. It can also create an
# access key for local testing.
#
# Deploy:
#   terraform -chdir=stacks/aws-watchmen-user init
#   terraform -chdir=stacks/aws-watchmen-user apply
#
# Print credentials after apply:
#   terraform -chdir=stacks/aws-watchmen-user output -raw access_key_id
#   terraform -chdir=stacks/aws-watchmen-user output -raw secret_access_key
#
# Destroy:
#   terraform -chdir=stacks/aws-watchmen-user destroy

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

variable "aws_region" {
  description = "AWS region used by the provider. IAM resources are global, but AWS still requires a provider region."
  type        = string
  default     = "us-east-1"
}

variable "user_name" {
  description = "IAM user name to create for Watchmen."
  type        = string
  default     = "watchmen-reader"
}

variable "create_access_key" {
  description = "Create an IAM access key for the Watchmen user."
  type        = bool
  default     = true
}

variable "extra_policy_arns" {
  description = "Additional IAM policy ARNs to attach if Watchmen needs more permissions in your account."
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Common tags applied to created IAM resources."
  type        = map(string)
  default = {
    managed_by = "terraform"
    app        = "watchmen"
    purpose    = "watchmen-aws-access"
  }
}

locals {
  # AWS managed read-only policies cover the account inventory, IAM/security
  # review, and CloudWatch/CloudTrail visibility that Watchmen needs to inspect
  # the account without granting mutation privileges.
  managed_policy_arns = toset(concat([
    "arn:aws:iam::aws:policy/ReadOnlyAccess",
    "arn:aws:iam::aws:policy/SecurityAudit",
    "arn:aws:iam::aws:policy/IAMReadOnlyAccess",
  ], var.extra_policy_arns))
}

resource "aws_iam_user" "watchmen" {
  name = var.user_name
  path = "/service/watchmen/"
  tags = var.tags
}

resource "aws_iam_user_policy_attachment" "managed" {
  for_each = local.managed_policy_arns

  user       = aws_iam_user.watchmen.name
  policy_arn = each.value
}

resource "aws_iam_access_key" "watchmen" {
  count = var.create_access_key ? 1 : 0

  user = aws_iam_user.watchmen.name
}

output "user_name" {
  value       = aws_iam_user.watchmen.name
  description = "IAM user created for Watchmen."
}

output "user_arn" {
  value       = aws_iam_user.watchmen.arn
  description = "IAM user ARN created for Watchmen."
}

output "access_key_id" {
  value       = var.create_access_key ? aws_iam_access_key.watchmen[0].id : null
  description = "Access key ID for Watchmen. Null when create_access_key is false."
  sensitive   = true
}

output "secret_access_key" {
  value       = var.create_access_key ? aws_iam_access_key.watchmen[0].secret : null
  description = "Secret access key for Watchmen. Store it securely; Terraform state also contains it."
  sensitive   = true
}
