# AWS IAM user for Watchmen app access.
#
# This configures a dedicated IAM user with read-only/security-review
# permissions suitable for connecting an AWS account to Watchmen. By default it
# reuses an existing user named watchmen-scanner, because the full AWS test
# environment stack can create that user too. Set create_user=true only when the
# user does not already exist in the account.
#
# Deploy:
#   terraform -chdir=stacks/aws-watchmen-user init
#   terraform -chdir=stacks/aws-watchmen-user apply
#
# Create the user instead of reusing an existing one:
#   terraform -chdir=stacks/aws-watchmen-user apply -var='create_user=true'
#
# Attach/update policies on an existing user:
#   terraform -chdir=stacks/aws-watchmen-user apply -var='manage_policy_attachments=true'
#
# Create a new access key:
#   terraform -chdir=stacks/aws-watchmen-user apply -var='create_access_key=true'
#
# Print credentials after creating a key:
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
  description = "IAM user name to configure for Watchmen."
  type        = string
  default     = "watchmen-scanner"
}

variable "create_user" {
  description = "Create the IAM user. Leave false to reuse an existing user with user_name."
  type        = bool
  default     = false
}

variable "create_access_key" {
  description = "Create an IAM access key for the Watchmen user."
  type        = bool
  default     = false
}

variable "manage_policy_attachments" {
  description = "Attach Watchmen read-only policies to an existing user. Policies are always attached when create_user is true."
  type        = bool
  default     = false
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

  watchmen_user_name = var.create_user ? aws_iam_user.watchmen[0].name : data.aws_iam_user.watchmen[0].user_name
  watchmen_user_arn  = var.create_user ? aws_iam_user.watchmen[0].arn : data.aws_iam_user.watchmen[0].arn
  manage_policies    = var.create_user || var.manage_policy_attachments
}

data "aws_iam_user" "watchmen" {
  count = var.create_user ? 0 : 1

  user_name = var.user_name
}

resource "aws_iam_user" "watchmen" {
  count = var.create_user ? 1 : 0

  name = var.user_name
  path = "/service/watchmen/"
  tags = var.tags
}

resource "aws_iam_user_policy_attachment" "managed" {
  for_each = local.manage_policies ? local.managed_policy_arns : []

  user       = local.watchmen_user_name
  policy_arn = each.value
}

data "aws_iam_policy_document" "lambda_function_url_read" {
  statement {
    sid = "ReadLambdaFunctionUrls"
    actions = [
      "lambda:ListFunctionUrlConfigs",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_user_policy" "lambda_function_url_read" {
  count = local.manage_policies ? 1 : 0

  name   = "watchmen-lambda-function-url-read"
  user   = local.watchmen_user_name
  policy = data.aws_iam_policy_document.lambda_function_url_read.json
}

data "aws_iam_policy_document" "lambda_logs_read" {
  statement {
    sid = "ReadLambdaCloudWatchLogs"
    actions = [
      "logs:DescribeLogGroups",
      "logs:DescribeLogStreams",
      "logs:FilterLogEvents",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_user_policy" "lambda_logs_read" {
  count = local.manage_policies ? 1 : 0

  name   = "watchmen-lambda-cloudwatch-logs-read"
  user   = local.watchmen_user_name
  policy = data.aws_iam_policy_document.lambda_logs_read.json
}

resource "aws_iam_access_key" "watchmen" {
  count = var.create_access_key ? 1 : 0

  user = local.watchmen_user_name
}

output "user_name" {
  value       = local.watchmen_user_name
  description = "IAM user configured for Watchmen."
}

output "user_arn" {
  value       = local.watchmen_user_arn
  description = "IAM user ARN configured for Watchmen."
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
