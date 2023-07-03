terraform {
  required_version = "1.4.6"

  #backend "s3" {}

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "4.65.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "2.20.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "2.9.0"
    }
    time = {
      source  = "hashicorp/time"
      version = "0.9.1"
    }
  }
}

data "aws_caller_identity" "current" {} # used for accesing Account ID and ARN

provider "aws" {
  region = var.region
  default_tags {
    tags = {
      "cb:user"        = "acaternberg"
      "cb:owner"       = "professional-services"
      "cb:environment" = "demo"
      "cb:environment"     = "ps-dev"
      "ps-genetes/stack"   = "eks-tf"
      "ps-genetes/cluster" = var.cluster_name
      "kubernetes.io/cluster/${var.cluster_name}" = "owned"
    }
  }
}
