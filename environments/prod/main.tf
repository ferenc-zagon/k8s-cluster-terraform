provider "aws" {
  region = "eu-central-1"
}

module "vpc" {
  source = "../../modules/vpc"

  environment          = "prod"
  aws_region           = "eu-central-1"
  vpc_cidr             = "10.200.0.0/16"
  public_subnet_cidrs  = ["10.200.1.0/24", "10.200.2.0/24", "10.200.3.0/24"]
  private_subnet_cidrs = ["10.200.10.0/24", "10.200.11.0/24", "10.200.12.0/24"]
}

module "k8s_cluster" {
  source = "../../modules/k8s-cluster"

  environment     = "prod"
  vpc_id          = module.vpc.vpc_id
  subnet_ids      = module.vpc.private_subnet_ids
  cluster_version = "1.30"
}

provider "helm" {
  kubernetes {
    host                   = module.k8s_cluster.cluster_endpoint
    cluster_ca_certificate = base64decode(module.k8s_cluster.cluster_certificate_authority_data)

    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      args        = ["eks", "get-token", "--cluster-name", module.k8s_cluster.cluster_name]
      command     = "aws"
    }
  }
}

module "k8s_addons" {
  source = "../../modules/k8s-addons"

  cluster_name                       = module.k8s_cluster.cluster_name
  cluster_endpoint                   = module.k8s_cluster.cluster_endpoint
  cluster_certificate_authority_data = module.k8s_cluster.cluster_certificate_authority_data
}