# Minimal EKS cluster for testing the Watchmen eBPF agent DaemonSet.
#
# Deploy:
#   terraform -chdir=stacks/aws-eks-cluster init
#   terraform -chdir=stacks/aws-eks-cluster apply
#
# Get credentials after creation:
#   aws eks update-kubeconfig --region us-east-1 --name watchmen-test
#
# Deploy the Watchmen agent and trace-test services:
#   WATCHMEN_AGENT_SECRET='...' scripts/deploy-watchmen-agent-eks.sh
#
# Destroy:
#   terraform -chdir=stacks/aws-eks-cluster destroy

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

data "aws_caller_identity" "current" {}

variable "aws_region" {
  description = "AWS region for the EKS test cluster."
  type        = string
  default     = "us-east-1"
}

variable "cluster_name" {
  description = "EKS cluster name."
  type        = string
  default     = "watchmen-test"
}

variable "k8s_version" {
  description = "Optional EKS Kubernetes version. Leave null to use the AWS default supported version."
  type        = string
  default     = null
}

variable "vpc_cidr" {
  description = "CIDR range for the test VPC."
  type        = string
  default     = "10.90.0.0/16"
}

variable "node_instance_types" {
  description = "EC2 instance types for the EKS managed node group."
  type        = list(string)
  default     = ["t3.medium"]
}

variable "node_desired_size" {
  description = "Desired node count."
  type        = number
  default     = 2
}

variable "node_min_size" {
  description = "Minimum node count."
  type        = number
  default     = 1
}

variable "node_max_size" {
  description = "Maximum node count."
  type        = number
  default     = 3
}

variable "node_disk_size_gb" {
  description = "Node root volume size in GB."
  type        = number
  default     = 30
}

variable "endpoint_public_access_cidrs" {
  description = "CIDR ranges allowed to reach the public Kubernetes API endpoint."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "tags" {
  description = "Common tags applied to AWS resources."
  type        = map(string)
  default = {
    managed_by = "terraform"
    app        = "watchmen"
    purpose    = "eks-agent-test"
  }
}

locals {
  name = var.cluster_name
}

data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  azs = slice(data.aws_availability_zones.available.names, 0, 2)
}

resource "aws_vpc" "test" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(var.tags, {
    Name = "${local.name}-vpc"
  })
}

resource "aws_internet_gateway" "test" {
  vpc_id = aws_vpc.test.id

  tags = merge(var.tags, {
    Name = "${local.name}-igw"
  })
}

resource "aws_subnet" "public" {
  for_each = {
    for index, az in local.azs : az => index
  }

  vpc_id                  = aws_vpc.test.id
  availability_zone       = each.key
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, each.value)
  map_public_ip_on_launch = true

  tags = merge(var.tags, {
    Name                                  = "${local.name}-public-${each.key}"
    "kubernetes.io/cluster/${local.name}" = "shared"
    "kubernetes.io/role/elb"              = "1"
  })
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.test.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.test.id
  }

  tags = merge(var.tags, {
    Name = "${local.name}-public"
  })
}

resource "aws_route_table_association" "public" {
  for_each = aws_subnet.public

  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}

data "aws_iam_policy_document" "eks_cluster_assume_role" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["eks.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "cluster" {
  name               = "${local.name}-cluster-role"
  assume_role_policy = data.aws_iam_policy_document.eks_cluster_assume_role.json
  tags               = var.tags
}

resource "aws_iam_role_policy_attachment" "cluster_policy" {
  role       = aws_iam_role.cluster.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

resource "aws_security_group" "cluster" {
  name        = "${local.name}-cluster"
  description = "EKS cluster security group"
  vpc_id      = aws_vpc.test.id

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "${local.name}-cluster"
  })
}

resource "aws_eks_cluster" "test" {
  name     = local.name
  role_arn = aws_iam_role.cluster.arn
  version  = var.k8s_version

  vpc_config {
    subnet_ids              = values(aws_subnet.public)[*].id
    security_group_ids      = [aws_security_group.cluster.id]
    endpoint_private_access = false
    endpoint_public_access  = true
    public_access_cidrs     = var.endpoint_public_access_cidrs
  }

  access_config {
    authentication_mode                         = "API_AND_CONFIG_MAP"
    bootstrap_cluster_creator_admin_permissions = true
  }

  tags = var.tags

  depends_on = [
    aws_iam_role_policy_attachment.cluster_policy,
  ]
}

data "aws_iam_policy_document" "eks_node_assume_role" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "node" {
  name               = "${local.name}-node-role"
  assume_role_policy = data.aws_iam_policy_document.eks_node_assume_role.json
  tags               = var.tags
}

resource "aws_iam_role_policy_attachment" "node_worker" {
  role       = aws_iam_role.node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "node_cni" {
  role       = aws_iam_role.node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

resource "aws_iam_role_policy_attachment" "node_registry" {
  role       = aws_iam_role.node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_eks_node_group" "primary" {
  cluster_name    = aws_eks_cluster.test.name
  node_group_name = "primary"
  node_role_arn   = aws_iam_role.node.arn
  subnet_ids      = values(aws_subnet.public)[*].id
  capacity_type   = "ON_DEMAND"
  disk_size       = var.node_disk_size_gb
  instance_types  = var.node_instance_types

  scaling_config {
    desired_size = var.node_desired_size
    min_size     = var.node_min_size
    max_size     = var.node_max_size
  }

  update_config {
    max_unavailable = 1
  }

  labels = {
    "watchmen.io/test-node" = "true"
  }

  tags = var.tags

  depends_on = [
    aws_iam_role_policy_attachment.node_worker,
    aws_iam_role_policy_attachment.node_cni,
    aws_iam_role_policy_attachment.node_registry,
  ]
}

output "cluster_name" {
  value       = aws_eks_cluster.test.name
  description = "EKS cluster name."
}

output "cluster_endpoint" {
  value       = aws_eks_cluster.test.endpoint
  description = "EKS Kubernetes API endpoint."
}

output "cluster_arn" {
  value       = aws_eks_cluster.test.arn
  description = "EKS cluster ARN."
}

output "node_role_arn" {
  value       = aws_iam_role.node.arn
  description = "IAM role used by EKS managed nodes."
}

output "update_kubeconfig" {
  value       = "aws eks update-kubeconfig --region ${var.aws_region} --name ${aws_eks_cluster.test.name}"
  description = "Command to configure kubectl for this cluster."
}

output "deploy_agent" {
  value       = "WATCHMEN_AGENT_SECRET='...' AWS_REGION='${var.aws_region}' EKS_CLUSTER_NAME='${aws_eks_cluster.test.name}' scripts/deploy-watchmen-agent-eks.sh"
  description = "Command template to deploy the Watchmen agent and trace-test services."
}
