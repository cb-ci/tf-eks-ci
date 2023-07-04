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

provider "kubernetes" {
  host                   = module.base.cluster_endpoint
  cluster_ca_certificate = base64decode(module.base.cluster_certificate_authority_data)
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args = ["eks", "get-token", "--cluster-name", module.base.cluster_name]
  }
}

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
