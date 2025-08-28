terraform {
  required_version = ">= 1.6.0"
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.0" }
  }
}

provider "aws" { region = var.region }

module "vpc" {
  source = "terraform-aws-modules/vpc/aws"
  name   = "${var.cluster_name}-vpc"
  cidr   = "10.0.0.0/16"

  azs             = ["${var.region}a","${var.region}b","${var.region}c"]
  public_subnets  = ["10.0.1.0/24","10.0.2.0/24","10.0.3.0/24"]
  private_subnets = ["10.0.11.0/24","10.0.12.0/24","10.0.13.0/24"]

  enable_nat_gateway = true
  single_nat_gateway = true
}

module "eks" {
  source          = "terraform-aws-modules/eks/aws"
  version         = "~> 20.0"

  cluster_name    = var.cluster_name
  cluster_version = "1.29"

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  enable_irsa = true
  manage_aws_auth_configmap = true

  eks_managed_node_groups = {
    default = {
      desired_size  = 2
      min_size      = 1
      max_size      = 3
      instance_types = ["t3.medium"]
    }
  }
}
