terraform {
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.0" }
    tls = { source = "hashicorp/tls", version = "~> 4.0" }
  }
  required_version = ">= 1.6"

  backend "s3" {
    key    = "prod/terraform.tfstate"
    region = "eu-west-1"
  }
}

provider "aws" {
  region = var.region
  default_tags {
    tags = local.common_tags
  }
}

locals {
  common_tags = {
    Project     = var.project
    Environment = "prod"
    ManagedBy   = "terraform"
  }
}

module "vpc" {
  source          = "../../modules/vpc"
  name            = "${var.project}-vpc"
  cidr            = "10.0.0.0/16"
  azs             = ["${var.region}a", "${var.region}b"]
  public_subnets  = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnets = ["10.0.11.0/24", "10.0.12.0/24"]
  tags            = local.common_tags
}

module "eks" {
  source             = "../../modules/eks"
  cluster_name       = "${var.project}-cluster"
  private_subnet_ids = module.vpc.private_subnet_ids
  instance_types     = ["t3.medium"]
  desired_size       = 2
  min_size           = 1
  max_size           = 4
  tags               = local.common_tags
}

module "codebuild" {
  source           = "../../modules/codebuild"
  project          = var.project
  tfstate_bucket   = var.tfstate_bucket
  eks_cluster_name = module.eks.cluster_name
  tags             = local.common_tags
}

resource "aws_dynamodb_table" "environments" {
  name         = "${var.project}-environments"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "env_id"

  attribute {
    name = "env_id"
    type = "S"
  }

  ttl {
    attribute_name = "expires_at"
    enabled        = true
  }

  tags = local.common_tags
}

resource "aws_secretsmanager_secret" "entra" {
  name                    = "idp/entra-credentials"
  recovery_window_in_days = 7
  tags                    = local.common_tags
}

resource "aws_secretsmanager_secret" "grafana" {
  name                    = "idp/grafana-credentials"
  recovery_window_in_days = 7
  tags                    = local.common_tags
}

resource "aws_secretsmanager_secret" "ses" {
  name                    = "idp/ses-config"
  recovery_window_in_days = 7
  tags                    = local.common_tags
}
