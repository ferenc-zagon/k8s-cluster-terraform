provider "aws" {
  region = "eu-central-1"
}

module "vpc" {
  source = "../../modules/vpc"

  environment          = "dev"
  cluster_name         = "dev-k8s-cluster"
  aws_region           = "eu-central-1"
  vpc_cidr             = "10.100.0.0/16"
  public_subnet_cidrs  = ["10.100.1.0/24", "10.100.2.0/24"]
  private_subnet_cidrs = ["10.100.10.0/24", "10.100.11.0/24"]
}

module "k8s_cluster" {
  source = "../../modules/k8s-cluster"

  environment     = "dev"
  cluster_name    = "dev-eks-cluster"
  vpc_id          = module.vpc.vpc_id
  subnet_ids      = module.vpc.private_subnet_ids
  cluster_version = "1.30"
}

provider "kubernetes" {
  host                   = module.k8s_cluster.cluster_endpoint
  cluster_ca_certificate = base64decode(module.k8s_cluster.cluster_certificate_authority_data)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    args        = ["eks", "get-token", "--cluster-name", module.k8s_cluster.cluster_name]
    command     = "aws"
  }
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

provider "kubectl" {
  host                   = module.k8s_cluster.cluster_endpoint
  cluster_ca_certificate = base64decode(module.k8s_cluster.cluster_certificate_authority_data)
  load_config_file       = false

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    args        = ["eks", "get-token", "--cluster-name", module.k8s_cluster.cluster_name]
    command     = "aws"
  }
}

module "k8s_addons" {
  source = "../../modules/k8s-addons"

  cluster_name                       = module.k8s_cluster.cluster_name
  cluster_endpoint                   = module.k8s_cluster.cluster_endpoint
  cluster_certificate_authority_data = module.k8s_cluster.cluster_certificate_authority_data
  karpenter_node_role_name           = module.k8s_cluster.karpenter_node_role_name
  karpenter_controller_role_arn      = module.k8s_cluster.karpenter_controller_role_arn
  gitops_repo_url                    = "https://github.com/ferenc-zagon/Terraform-lab.git"
  gitops_repo_revision               = "master"

  depends_on = [module.k8s_cluster]
}