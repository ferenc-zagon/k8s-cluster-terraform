terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "= 6.64.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.12.0"
    }
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = ">= 1.14.0"
    }
  }
}

data "aws_region" "current" {}

# 1. Karpenter (Cluster Autoscaling Controller)
resource "helm_release" "karpenter" {
  name             = "karpenter"
  repository       = "oci://public.ecr.aws/karpenter"
  chart            = "karpenter"
  namespace        = "kube-system"
  version          = "1.0.1"
  create_namespace = false

  values = [
    yamlencode({
      settings = {
        clusterName     = var.cluster_name
        clusterEndpoint = var.cluster_endpoint
        aws = {
          region = data.aws_region.current.region
        }
      }
      serviceAccount = {
        annotations = {
          "eks.amazonaws.com/role-arn" = var.karpenter_controller_role_arn
        }
      }
      env = [
        {
          name  = "AWS_REGION"
          value = data.aws_region.current.region
        },
        {
          name  = "AWS_DEFAULT_REGION"
          value = data.aws_region.current.region
        }
      ]
    })
  ]
}

# 2. Metrics Server
resource "helm_release" "metrics_server" {
  name       = "metrics-server"
  repository = "https://kubernetes-sigs.github.io/metrics-server/"
  chart      = "metrics-server"
  namespace  = "kube-system"
  version    = "3.12.1"

  values = [
    yamlencode({
      args = [
        "--kubelet-insecure-tls",
        "--kubelet-preferred-address-types=InternalIP,ExternalIP,Hostname"
      ]
    })
  ]
}

# 2. Ingress NGINX Controller
resource "helm_release" "ingress_nginx" {
  name             = "ingress-nginx"
  repository       = "https://kubernetes.github.io/ingress-nginx"
  chart            = "ingress-nginx"
  namespace        = "ingress-nginx"
  version          = "4.10.0"
  create_namespace = true

  set {
    name  = "controller.service.annotations.service\\.beta\\.kubernetes\\.io/aws-load-balancer-type"
    value = "nlb"
  }

  depends_on = [
    helm_release.metrics_server
  ]
}

# 3. ArgoCD (GitOps Controller)
resource "helm_release" "argocd" {
  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  namespace        = "argocd"
  version          = "6.7.11"
  create_namespace = true

  set {
    name  = "server.service.type"
    value = "ClusterIP"
  }

  depends_on = [
    helm_release.ingress_nginx
  ]
}