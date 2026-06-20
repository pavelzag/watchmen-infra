# AWS test environment for Watchmen.
#
# This mirrors the broad GCP testing stack in ./gcp:
# - S3 buckets for logs/data/backups and intentionally interesting bucket cases
# - IAM users/roles/access keys for normal and risky identity scenarios
# - Lambda functions and public HTTP API routes that mirror Cloud Run services
# - Security groups and EC2 instances that mirror firewall/VM findings
# - RDS, Glue databases, SNS/SQS, and Secrets Manager test resources
#
# Deploy:
#   terraform -chdir=stacks/aws-test-environment init
#   terraform -chdir=stacks/aws-test-environment apply
#
# Destroy:
#   terraform -chdir=stacks/aws-test-environment destroy

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.4"
    }
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

data "aws_caller_identity" "current" {}

variable "aws_region" {
  description = "AWS region for Watchmen test resources."
  type        = string
  default     = "us-east-1"
}

variable "name_prefix" {
  description = "Prefix used for created resources."
  type        = string
  default     = "wm-test"
}

variable "create_access_keys" {
  description = "Create IAM access keys for test users. Secrets are stored in Terraform state."
  type        = bool
  default     = true
}

variable "create_rds" {
  description = "Create a small public RDS MySQL instance for database inventory/testing."
  type        = bool
  default     = true
}

variable "create_ec2" {
  description = "Create small EC2 instances for compute inventory/testing."
  type        = bool
  default     = true
}

variable "tags" {
  description = "Common tags applied to AWS resources."
  type        = map(string)
  default = {
    managed_by = "terraform"
    app        = "watchmen"
    purpose    = "watchmen-test-environment"
  }
}

locals {
  account_id = data.aws_caller_identity.current.account_id
  bucket_names = {
    logs                  = "${var.name_prefix}-${local.account_id}-${var.aws_region}-logs"
    data                  = "${var.name_prefix}-${local.account_id}-${var.aws_region}-data"
    backups               = "${var.name_prefix}-${local.account_id}-${var.aws_region}-backups"
    attack_public_data    = "${var.name_prefix}-${local.account_id}-${var.aws_region}-attack-public-data"
    attack_public_uploads = "${var.name_prefix}-${local.account_id}-${var.aws_region}-attack-public-uploads"
  }
  lambda_functions = {
    hello = {
      name        = "${var.name_prefix}-hello"
      route       = "/hello"
      description = "Normal hello test service"
      env         = {}
    }
    api = {
      name        = "${var.name_prefix}-api"
      route       = "/api"
      description = "Normal API test service"
      env         = {}
    }
    attack_leaked_aws_creds = {
      name        = "wm-attack-leaked-aws-creds"
      route       = "/attack/leaked-aws-creds"
      description = "Lambda with demo AWS credentials in environment variables"
      env = {
        AWS_ACCESS_KEY_ID     = "AKIAIOSFODNN7EXAMPLE"
        AWS_SECRET_ACCESS_KEY = "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"
      }
    }
    attack_stripe_key = {
      name        = "wm-attack-stripe-key"
      route       = "/attack/stripe-key"
      description = "Lambda with demo Stripe key in environment variables"
      env = {
        STRIPE_SECRET_KEY = "sk_WATCHMEN_DEMO_NOT_A_REAL_KEY_ABCDE99"
      }
    }
    attack_github_token = {
      name        = "wm-attack-github-runner"
      route       = "/attack/github-runner"
      description = "Lambda with demo GitHub token in environment variables"
      env = {
        GITHUB_TOKEN = "ghp_WatchmenDemoFakeTokenABCDEFGHIJKLMN01"
      }
    }
    attack_db_password_env = {
      name        = "wm-attack-db-password-env"
      route       = "/attack/db-password-env"
      description = "Lambda with demo database password in environment variables"
      env = {
        DATABASE_PASSWORD = "WatchmenDemoDbPasswordSecretKey2024"
        DATABASE_URL      = "postgresql://admin:WatchmenDemoDbPasswordSecretKey2024@10.0.0.5:5432/prod"
      }
    }
    attack_public_internal_api = {
      name        = "wm-attack-public-internal-api"
      route       = "/attack/public-internal-api"
      description = "Public API route backed by Lambda with elevated execution role"
      env         = {}
    }
    attack_public_api = {
      name        = "wm-attack-public-api"
      route       = "/attack/public-api"
      description = "Public API route backed by Lambda with admin execution role"
      env         = {}
    }
  }
  iam_users = {
    etl                 = "${var.name_prefix}-etl"
    reporting           = "${var.name_prefix}-reporting"
    cicd                = "${var.name_prefix}-cicd"
    github_ci           = "github-ci"
    watchmen_reader     = "watchmen-reader"
    attack_escalation   = "wm-attack-escalation-user"
    attack_owner        = "wm-attack-owner-user"
    attack_multikey     = "wm-attack-multikey-user"
    attack_exposed_cicd = "wm-attack-exposed-cicd"
  }
}

resource "aws_s3_bucket" "buckets" {
  for_each = local.bucket_names

  bucket        = each.value
  force_destroy = true

  tags = merge(var.tags, {
    Name = each.value
    role = each.key
  })
}

resource "aws_s3_bucket_versioning" "buckets" {
  for_each = aws_s3_bucket.buckets

  bucket = each.value.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "logs" {
  bucket = aws_s3_bucket.buckets["logs"].id

  rule {
    id     = "delete-after-30-days"
    status = "Enabled"

    expiration {
      days = 30
    }
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "buckets" {
  for_each = aws_s3_bucket.buckets

  bucket = each.value.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "private_buckets" {
  for_each = {
    for key, bucket in aws_s3_bucket.buckets : key => bucket
    if !contains(["attack_public_uploads"], key)
  }

  bucket                  = each.value.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_public_access_block" "attack_public_uploads" {
  bucket                  = aws_s3_bucket.buckets["attack_public_uploads"].id
  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_ownership_controls" "attack_public_uploads" {
  bucket = aws_s3_bucket.buckets["attack_public_uploads"].id

  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_policy" "attack_public_uploads" {
  bucket = aws_s3_bucket.buckets["attack_public_uploads"].id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AllowPublicObjectReadForWatchmenTest"
        Effect    = "Allow"
        Principal = "*"
        Action    = ["s3:GetObject"]
        Resource  = "${aws_s3_bucket.buckets["attack_public_uploads"].arn}/*"
      }
    ]
  })

  depends_on = [aws_s3_bucket_public_access_block.attack_public_uploads]
}

resource "aws_iam_user" "users" {
  for_each = local.iam_users

  name = each.value
  path = "/service/watchmen-test/"

  tags = merge(var.tags, {
    role = each.key
  })
}

resource "aws_iam_access_key" "primary" {
  for_each = var.create_access_keys ? aws_iam_user.users : {}

  user = each.value.name
}

resource "aws_iam_access_key" "attack_multikey_extra" {
  count = var.create_access_keys ? 1 : 0

  user = aws_iam_user.users["attack_multikey"].name
}

resource "aws_iam_access_key" "attack_exposed_cicd_extra" {
  count = var.create_access_keys ? 1 : 0

  user = aws_iam_user.users["attack_exposed_cicd"].name
}

resource "aws_iam_user_policy_attachment" "watchmen_reader_readonly" {
  user       = aws_iam_user.users["watchmen_reader"].name
  policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}

resource "aws_iam_user_policy_attachment" "watchmen_reader_security_audit" {
  user       = aws_iam_user.users["watchmen_reader"].name
  policy_arn = "arn:aws:iam::aws:policy/SecurityAudit"
}

resource "aws_iam_user_policy_attachment" "watchmen_reader_iam_readonly" {
  user       = aws_iam_user.users["watchmen_reader"].name
  policy_arn = "arn:aws:iam::aws:policy/IAMReadOnlyAccess"
}

resource "aws_iam_user_policy_attachment" "reporting_readonly" {
  user       = aws_iam_user.users["reporting"].name
  policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}

resource "aws_iam_user_policy_attachment" "cicd_power_user" {
  user       = aws_iam_user.users["cicd"].name
  policy_arn = "arn:aws:iam::aws:policy/PowerUserAccess"
}

resource "aws_iam_user_policy_attachment" "attack_escalation_admin" {
  user       = aws_iam_user.users["attack_escalation"].name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

resource "aws_iam_user_policy_attachment" "attack_owner_admin" {
  user       = aws_iam_user.users["attack_owner"].name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

resource "aws_iam_user_policy_attachment" "attack_exposed_cicd_admin" {
  user       = aws_iam_user.users["attack_exposed_cicd"].name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

data "aws_iam_policy_document" "etl_storage" {
  statement {
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject",
      "s3:ListBucket",
    ]
    resources = [
      aws_s3_bucket.buckets["logs"].arn,
      "${aws_s3_bucket.buckets["logs"].arn}/*",
      aws_s3_bucket.buckets["data"].arn,
      "${aws_s3_bucket.buckets["data"].arn}/*",
    ]
  }
}

resource "aws_iam_user_policy" "etl_storage" {
  name   = "${var.name_prefix}-etl-storage"
  user   = aws_iam_user.users["etl"].name
  policy = data.aws_iam_policy_document.etl_storage.json
}

data "archive_file" "lambda" {
  type        = "zip"
  output_path = "${path.module}/lambda_payload.zip"

  source {
    filename = "index.py"
    content  = <<-PY
      import json
      import os
      import time

      def handler(event, context):
          payload = {
              "service": os.environ.get("SERVICE_NAME", "watchmen-test"),
              "path": event.get("rawPath") or event.get("path") or "/",
              "requestId": event.get("requestContext", {}).get("requestId"),
              "time": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
          }
          return {
              "statusCode": 200,
              "headers": {"content-type": "application/json"},
              "body": json.dumps(payload),
          }
    PY
  }
}

data "aws_iam_policy_document" "lambda_assume_role" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "lambda" {
  for_each = local.lambda_functions

  name               = "${each.value.name}-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json
  tags               = var.tags
}

resource "aws_iam_role_policy_attachment" "lambda_basic" {
  for_each = aws_iam_role.lambda

  role       = each.value.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "lambda_attack_escalation_admin" {
  role       = aws_iam_role.lambda["attack_public_internal_api"].name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

resource "aws_iam_role_policy_attachment" "lambda_attack_public_api_admin" {
  role       = aws_iam_role.lambda["attack_public_api"].name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

resource "aws_lambda_function" "functions" {
  for_each = local.lambda_functions

  function_name    = each.value.name
  description      = each.value.description
  role             = aws_iam_role.lambda[each.key].arn
  handler          = "index.handler"
  runtime          = "python3.12"
  filename         = data.archive_file.lambda.output_path
  source_code_hash = data.archive_file.lambda.output_base64sha256
  timeout          = 10
  memory_size      = 128

  environment {
    variables = merge(each.value.env, {
      SERVICE_NAME = each.value.name
    })
  }

  tags = var.tags

  depends_on = [aws_iam_role_policy_attachment.lambda_basic]
}

resource "aws_cloudwatch_log_group" "lambda" {
  for_each = local.lambda_functions

  name              = "/aws/lambda/${each.value.name}"
  retention_in_days = 30
  tags              = var.tags
}

resource "aws_apigatewayv2_api" "test" {
  name          = "${var.name_prefix}-http-api"
  protocol_type = "HTTP"
  tags          = var.tags
}

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.test.id
  name        = "$default"
  auto_deploy = true
  tags        = var.tags
}

resource "aws_apigatewayv2_integration" "lambda" {
  for_each = local.lambda_functions

  api_id                 = aws_apigatewayv2_api.test.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.functions[each.key].invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "lambda" {
  for_each = local.lambda_functions

  api_id    = aws_apigatewayv2_api.test.id
  route_key = "ANY ${each.value.route}"
  target    = "integrations/${aws_apigatewayv2_integration.lambda[each.key].id}"
}

resource "aws_lambda_permission" "api_gateway" {
  for_each = local.lambda_functions

  statement_id  = "AllowExecutionFromHttpApi-${each.key}"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.functions[each.key].function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.test.execution_arn}/*/*"
}

resource "aws_vpc" "test" {
  cidr_block           = "10.96.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-vpc"
  })
}

resource "aws_internet_gateway" "test" {
  vpc_id = aws_vpc.test.id

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-igw"
  })
}

data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_subnet" "public" {
  count = 2

  vpc_id                  = aws_vpc.test.id
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  cidr_block              = cidrsubnet(aws_vpc.test.cidr_block, 8, count.index)
  map_public_ip_on_launch = true

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-public-${count.index + 1}"
  })
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.test.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.test.id
  }

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-public"
  })
}

resource "aws_route_table_association" "public" {
  count = length(aws_subnet.public)

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_security_group" "test" {
  name        = "${var.name_prefix}-default-like"
  description = "Default-like internal access for Watchmen tests"
  vpc_id      = aws_vpc.test.id

  ingress {
    description = "Internal all traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["10.0.0.0/8"]
  }

  ingress {
    description = "Open ICMP"
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-default-like"
  })
}

resource "aws_security_group" "attack_open_ssh" {
  name        = "wm-attack-open-ssh"
  description = "SSH open broadly for Watchmen test finding"
  vpc_id      = aws_vpc.test.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = var.tags
}

resource "aws_security_group" "attack_open_rdp" {
  name        = "wm-attack-open-rdp"
  description = "RDP open broadly for Watchmen test finding"
  vpc_id      = aws_vpc.test.id

  ingress {
    from_port   = 3389
    to_port     = 3389
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = var.tags
}

resource "aws_security_group" "attack_open_db_ports" {
  name        = "wm-attack-open-db-ports"
  description = "Database ports open broadly for Watchmen test finding"
  vpc_id      = aws_vpc.test.id

  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 6379
    to_port     = 6379
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = var.tags
}

resource "aws_security_group" "attack_allow_all" {
  name        = "wm-attack-allow-all-ingress"
  description = "Allow all ingress for Watchmen test finding"
  vpc_id      = aws_vpc.test.id

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = var.tags
}

data "aws_ami" "debian" {
  count       = var.create_ec2 ? 1 : 0
  most_recent = true
  owners      = ["136693071363"]

  filter {
    name   = "name"
    values = ["debian-12-amd64-*"]
  }
}

resource "aws_iam_role" "ec2_attack_privileged" {
  name               = "wm-attack-privileged-ec2-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json
  tags               = var.tags
}

data "aws_iam_policy_document" "ec2_assume_role" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role_policy_attachment" "ec2_attack_privileged_admin" {
  role       = aws_iam_role.ec2_attack_privileged.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

resource "aws_iam_instance_profile" "ec2_attack_privileged" {
  name = "wm-attack-privileged-ec2-profile"
  role = aws_iam_role.ec2_attack_privileged.name
}

resource "aws_instance" "test" {
  count = var.create_ec2 ? 1 : 0

  ami                         = data.aws_ami.debian[0].id
  instance_type               = "t3.micro"
  subnet_id                   = aws_subnet.public[0].id
  vpc_security_group_ids      = [aws_security_group.test.id]
  associate_public_ip_address = false

  root_block_device {
    volume_size = 10
    volume_type = "gp3"
  }

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-vm"
  })
}

resource "aws_instance" "attack_privileged" {
  count = var.create_ec2 ? 1 : 0

  ami                         = data.aws_ami.debian[0].id
  instance_type               = "t3.micro"
  subnet_id                   = aws_subnet.public[0].id
  vpc_security_group_ids      = [aws_security_group.attack_open_ssh.id]
  associate_public_ip_address = true
  iam_instance_profile        = aws_iam_instance_profile.ec2_attack_privileged.name

  root_block_device {
    volume_size = 10
    volume_type = "gp3"
  }

  tags = merge(var.tags, {
    Name = "wm-attack-privileged-vm"
  })
}

resource "aws_instance" "attack_exposed" {
  count = var.create_ec2 ? 1 : 0

  ami                         = data.aws_ami.debian[0].id
  instance_type               = "t3.micro"
  subnet_id                   = aws_subnet.public[0].id
  vpc_security_group_ids      = [aws_security_group.attack_allow_all.id]
  associate_public_ip_address = true

  root_block_device {
    volume_size = 10
    volume_type = "gp3"
  }

  tags = merge(var.tags, {
    Name = "wm-attack-exposed-vm"
  })
}

resource "aws_instance" "attack_dev" {
  count = var.create_ec2 ? 1 : 0

  ami                         = data.aws_ami.debian[0].id
  instance_type               = "t3.micro"
  subnet_id                   = aws_subnet.public[1].id
  vpc_security_group_ids      = [aws_security_group.attack_open_rdp.id, aws_security_group.attack_open_db_ports.id]
  associate_public_ip_address = true

  root_block_device {
    volume_size = 10
    volume_type = "gp3"
  }

  tags = merge(var.tags, {
    Name = "wm-attack-dev-instance"
  })
}

resource "aws_db_subnet_group" "test" {
  count = var.create_rds ? 1 : 0

  name       = "${var.name_prefix}-db-subnets"
  subnet_ids = aws_subnet.public[*].id
  tags       = var.tags
}

resource "aws_db_instance" "test" {
  count = var.create_rds ? 1 : 0

  identifier              = "${var.name_prefix}-sql"
  allocated_storage       = 20
  engine                  = "mysql"
  engine_version          = "8.0"
  instance_class          = "db.t3.micro"
  db_name                 = "watchmentest"
  username                = "admin"
  password                = "WatchmenDemoDbPasswordSecretKey2024"
  db_subnet_group_name    = aws_db_subnet_group.test[0].name
  vpc_security_group_ids  = [aws_security_group.attack_open_db_ports.id]
  publicly_accessible     = true
  skip_final_snapshot     = true
  deletion_protection     = false
  storage_encrypted       = true
  backup_retention_period = 1

  tags = var.tags
}

resource "aws_glue_catalog_database" "databases" {
  for_each = toset([
    "wm_test_analytics",
    "wm_test_logs",
    "wm_test_ml_features",
  ])

  name = each.value
}

resource "aws_sns_topic" "topics" {
  for_each = toset([
    "wm-test-alerts",
    "wm-test-events",
    "wm-test-metrics",
    "container-analysis-notes-v1",
    "container-analysis-occurrences-v1",
    "container-analysis-notes-v1beta1",
    "container-analysis-occurrences-v1beta1",
  ])

  name = each.value
  tags = var.tags
}

resource "aws_sqs_queue" "queues" {
  for_each = aws_sns_topic.topics

  name = "${each.key}-queue"
  tags = var.tags
}

resource "aws_secretsmanager_secret" "secrets" {
  for_each = toset([
    "wm-test-api-key",
    "wm-test-db-password",
    "wm-test-jwt-secret",
  ])

  name                    = each.value
  recovery_window_in_days = 0
  tags                    = var.tags
}

resource "aws_secretsmanager_secret_version" "secrets" {
  for_each = aws_secretsmanager_secret.secrets

  secret_id = each.value.id
  secret_string = jsonencode({
    value = "WatchmenDemoSecret-${each.key}"
  })
}

output "account_id" {
  value = local.account_id
}

output "iam_users" {
  value = {
    for key, user in aws_iam_user.users : key => user.name
  }
}

output "watchmen_reader_access_key_id" {
  value       = var.create_access_keys ? aws_iam_access_key.primary["watchmen_reader"].id : null
  sensitive   = true
  description = "Access key ID for the Watchmen reader user."
}

output "watchmen_reader_secret_access_key" {
  value       = var.create_access_keys ? aws_iam_access_key.primary["watchmen_reader"].secret : null
  sensitive   = true
  description = "Secret access key for the Watchmen reader user."
}

output "buckets" {
  value = {
    for key, bucket in aws_s3_bucket.buckets : key => bucket.bucket
  }
}

output "lambda_functions" {
  value = {
    for key, fn in aws_lambda_function.functions : key => fn.function_name
  }
}

output "http_api_base_url" {
  value = aws_apigatewayv2_api.test.api_endpoint
}

output "ec2_instances" {
  value = {
    test              = var.create_ec2 ? aws_instance.test[0].id : null
    attack_privileged = var.create_ec2 ? aws_instance.attack_privileged[0].id : null
    attack_exposed    = var.create_ec2 ? aws_instance.attack_exposed[0].id : null
    attack_dev        = var.create_ec2 ? aws_instance.attack_dev[0].id : null
  }
}

output "rds_instance" {
  value = var.create_rds ? aws_db_instance.test[0].identifier : null
}

output "glue_databases" {
  value = sort([for database in aws_glue_catalog_database.databases : database.name])
}

output "sns_topics" {
  value = sort([for topic in aws_sns_topic.topics : topic.name])
}

output "sqs_queues" {
  value = sort([for queue in aws_sqs_queue.queues : queue.name])
}

output "secret_names" {
  value = sort([for secret in aws_secretsmanager_secret.secrets : secret.name])
}

