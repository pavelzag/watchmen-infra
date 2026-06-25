data "aws_caller_identity" "current" {}

locals {
  aws_generated_principal_arns  = var.create_aws_assumer_access_key_user && var.create_aws_role ? [aws_iam_user.watchmen_assumer[0].arn] : []
  aws_configured_principal_arns = concat(var.watchmen_server_principal_arns, local.aws_generated_principal_arns)

  aws_trusted_principal_arns = length(local.aws_configured_principal_arns) > 0 ? local.aws_configured_principal_arns : [
    "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root",
  ]

  aws_scanner_policy_arns = toset(concat([
    "arn:aws:iam::aws:policy/ReadOnlyAccess",
    "arn:aws:iam::aws:policy/SecurityAudit",
    "arn:aws:iam::aws:policy/IAMReadOnlyAccess",
  ], var.aws_extra_policy_arns))

  aws_manual_user_name_resolved = var.create_aws_manual_user ? aws_iam_user.watchmen_manual[0].name : data.aws_iam_user.watchmen_manual[0].user_name
}

resource "aws_iam_user" "watchmen_assumer" {
  count = var.create_aws_assumer_access_key_user && var.create_aws_role ? 1 : 0

  name = var.aws_assumer_user_name
  path = "/service/watchmen/"
  tags = var.tags
}

data "aws_iam_policy_document" "watchmen_assume_role" {
  count = var.create_aws_role ? 1 : 0

  statement {
    sid     = "AllowWatchmenAssumeRole"
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "AWS"
      identifiers = local.aws_trusted_principal_arns
    }

    condition {
      test     = "StringEquals"
      variable = "sts:ExternalId"
      values   = [var.aws_external_id]
    }
  }
}

resource "aws_iam_role" "watchmen_scanner" {
  count = var.create_aws_role ? 1 : 0

  name               = var.aws_role_name
  description        = "Read-only Watchmen scanner role assumed with an external ID."
  assume_role_policy = data.aws_iam_policy_document.watchmen_assume_role[0].json
  tags               = var.tags
}

resource "aws_iam_role_policy_attachment" "watchmen_managed" {
  for_each = var.create_aws_role ? local.aws_scanner_policy_arns : toset([])

  role       = aws_iam_role.watchmen_scanner[0].name
  policy_arn = each.value
}

data "aws_iam_policy_document" "watchmen_extra_read" {
  statement {
    sid = "ReadLambdaFunctionUrls"
    actions = [
      "lambda:ListFunctionUrlConfigs",
    ]
    resources = ["*"]
  }

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

resource "aws_iam_role_policy" "watchmen_extra_read" {
  count = var.create_aws_role ? 1 : 0

  name   = "watchmen-extra-read"
  role   = aws_iam_role.watchmen_scanner[0].id
  policy = data.aws_iam_policy_document.watchmen_extra_read.json
}

data "aws_iam_policy_document" "watchmen_assumer" {
  count = var.create_aws_assumer_access_key_user && var.create_aws_role ? 1 : 0

  statement {
    sid     = "AssumeWatchmenScannerRole"
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    resources = [
      aws_iam_role.watchmen_scanner[0].arn,
    ]

    condition {
      test     = "StringEquals"
      variable = "sts:ExternalId"
      values   = [var.aws_external_id]
    }
  }
}

resource "aws_iam_user_policy" "watchmen_assumer" {
  count = var.create_aws_assumer_access_key_user && var.create_aws_role ? 1 : 0

  name   = "watchmen-assume-scanner-role"
  user   = aws_iam_user.watchmen_assumer[0].name
  policy = data.aws_iam_policy_document.watchmen_assumer[0].json
}

resource "aws_iam_access_key" "watchmen_assumer" {
  count = var.create_aws_assumer_access_key_user && var.create_aws_role ? 1 : 0

  user = aws_iam_user.watchmen_assumer[0].name
}

resource "aws_iam_user" "watchmen_manual" {
  count = var.create_aws_manual_user ? 1 : 0

  name = var.aws_manual_user_name
  path = "/service/watchmen/"
  tags = var.tags
}

data "aws_iam_user" "watchmen_manual" {
  count = var.create_aws_manual_user ? 0 : 1

  user_name = var.aws_manual_user_name
}

resource "aws_iam_user_policy_attachment" "watchmen_manual_managed" {
  for_each = var.create_aws_manual_access_key_user ? local.aws_scanner_policy_arns : toset([])

  user       = local.aws_manual_user_name_resolved
  policy_arn = each.value
}

resource "aws_iam_user_policy" "watchmen_manual_extra_read" {
  count = var.create_aws_manual_access_key_user ? 1 : 0

  name   = "watchmen-extra-read"
  user   = local.aws_manual_user_name_resolved
  policy = data.aws_iam_policy_document.watchmen_extra_read.json
}

resource "aws_iam_access_key" "watchmen_manual" {
  count = var.create_aws_manual_access_key_user ? 1 : 0

  user = local.aws_manual_user_name_resolved
}
