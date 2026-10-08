terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "= 6.64.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.12.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.30.0"
    }
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = ">= 1.14.0"
    }
  }

  backend "s3" {
    bucket       = "platform-terraform-state-lock"
    key          = "k8s-platform/prod/terraform.tfstate"
    region       = "eu-central-1"
    use_lockfile = true
    encrypt      = true
  }
}