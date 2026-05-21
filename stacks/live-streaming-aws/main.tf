terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# -----------------------------------------------------------------------------
# Watchmen live trace streaming infrastructure for AWS
#
# CloudWatch Logs -> Subscription Filters -> Kinesis Data Stream
#
# Notes:
# - This covers near-real-time CloudWatch Logs-backed sources such as Lambda,
#   API Gateway execution/access logs, and application logs shipped from ECS,
#   EKS, or EC2.
# - ALB access logs are not included here because they are usually delivered to
#   S3 and need a separate S3 -> queue/consumer path.
# -----------------------------------------------------------------------------

provider "aws" {
  region = var.aws_region
}

variable "name_prefix" {
  description = "Prefix used for created resources."
  type        = string
  default     = "watchmen-live-trace"
}

variable "aws_region" {
  description = "AWS region for the Kinesis stream and related resources."
  type        = string
  default     = "us-east-1"
}

variable "aws_kinesis_shard_count" {
  description = "Shard count for the Watchmen Kinesis stream."
  type        = number
  default     = 1
}

variable "aws_log_group_names" {
  description = "Existing CloudWatch log group names to subscribe to the Watchmen stream."
  type        = list(string)
}

variable "aws_subscription_filter_pattern" {
  description = "CloudWatch Logs subscription filter pattern. Empty means forward every log event."
  type        = string
  default     = ""
}

variable "tags" {
  description = "Common tags applied to AWS resources."
  type        = map(string)
  default = {
    managed_by = "terraform"
    app        = "watchmen"
    purpose    = "live-trace-streaming"
  }
}

resource "aws_kinesis_stream" "watchmen_live_trace" {
  name             = "${var.name_prefix}-stream"
  shard_count      = var.aws_kinesis_shard_count
  retention_period = 24

  stream_mode_details {
    stream_mode = "PROVISIONED"
  }

  tags = var.tags
}

data "aws_iam_policy_document" "watchmen_cloudwatch_assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["logs.${var.aws_region}.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "watchmen_cloudwatch_to_kinesis" {
  name               = "${var.name_prefix}-cwlogs-role"
  assume_role_policy = data.aws_iam_policy_document.watchmen_cloudwatch_assume_role.json

  tags = var.tags
}

data "aws_iam_policy_document" "watchmen_cloudwatch_to_kinesis" {
  statement {
    effect = "Allow"
    actions = [
      "kinesis:DescribeStream",
      "kinesis:DescribeStreamSummary",
      "kinesis:ListShards",
      "kinesis:PutRecord",
      "kinesis:PutRecords",
    ]
    resources = [aws_kinesis_stream.watchmen_live_trace.arn]
  }
}

resource "aws_iam_role_policy" "watchmen_cloudwatch_to_kinesis" {
  name   = "${var.name_prefix}-cwlogs-policy"
  role   = aws_iam_role.watchmen_cloudwatch_to_kinesis.id
  policy = data.aws_iam_policy_document.watchmen_cloudwatch_to_kinesis.json
}

resource "aws_cloudwatch_log_subscription_filter" "watchmen_live_trace" {
  for_each = toset(var.aws_log_group_names)

  name            = "${var.name_prefix}-${substr(md5(each.value), 0, 8)}"
  log_group_name  = each.value
  filter_pattern  = var.aws_subscription_filter_pattern
  destination_arn = aws_kinesis_stream.watchmen_live_trace.arn
  role_arn        = aws_iam_role.watchmen_cloudwatch_to_kinesis.arn
  distribution    = "ByLogStream"

  depends_on = [
    aws_iam_role_policy.watchmen_cloudwatch_to_kinesis,
  ]
}

output "aws_kinesis_stream_name" {
  value       = aws_kinesis_stream.watchmen_live_trace.name
  description = "Kinesis stream receiving subscribed CloudWatch log events."
}

output "aws_kinesis_stream_arn" {
  value       = aws_kinesis_stream.watchmen_live_trace.arn
  description = "Kinesis stream ARN for Watchmen live trace ingestion."
}

output "aws_cloudwatch_subscription_role_arn" {
  value       = aws_iam_role.watchmen_cloudwatch_to_kinesis.arn
  description = "IAM role ARN assumed by CloudWatch Logs to write to Kinesis."
}
