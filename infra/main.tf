terraform {
  required_version = ">= 1.10"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.69"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.7"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

module "nextjs" {
  source = "./modules/nextjs"

  name             = "deploy-aws-${local.environment}"
  build_path       = "${path.root}/../.open-next"
  deploy_artifacts = var.deploy_artifacts
  force_destroy    = local.is_preview
}