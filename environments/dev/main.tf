terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Remote state: never use local backend in shared environments
  # Uncomment and configure before applying:
  # backend "s3" {
  #   bucket         = "my-terraform-state-bucket"
  #   key            = "dev/terraform.tfstate"
  #   region         = "eu-west-1"
  #   encrypt        = true
  #   dynamodb_table = "terraform-locks"
  # }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = local.common_tags
  }
}

locals {
  environment = "dev"
  common_tags = {
    Environment = local.environment
    Project     = "secure-iac"
    ManagedBy   = "terraform"
  }
}

module "network" {
  source = "../../modules/network"

  environment          = local.environment
  vpc_cidr             = "10.10.0.0/16"
  private_subnet_cidrs = ["10.10.1.0/24", "10.10.2.0/24"]
  public_subnet_cidrs  = ["10.10.101.0/24", "10.10.102.0/24"]
  availability_zones   = ["eu-west-1a", "eu-west-1b"]

  # Dev: restrict to office/VPN range only, never 0.0.0.0/0
  allowed_ingress_cidrs = ["10.0.0.0/8"]

  flow_log_role_arn        = var.flow_log_role_arn
  flow_log_destination_arn = var.flow_log_destination_arn

  tags = local.common_tags
}

module "storage" {
  source = "../../modules/storage"

  bucket_name  = "secure-iac-dev-${var.account_id}"
  environment  = local.environment
  kms_key_id   = var.kms_key_id
  tags         = local.common_tags
}

module "iam" {
  source = "../../modules/iam"

  environment      = local.environment
  allowed_bucket   = module.storage.bucket_name
  tags             = local.common_tags
}
