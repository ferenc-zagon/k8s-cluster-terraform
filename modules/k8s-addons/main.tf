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
  }
}

# 1. Metrics Server
resource "helm_release" "metrics_server" {
  name             = "metrics-server"
  repository       = "https://kubernetes-sigs.github.io/metrics-server/"
  chart            = "metrics-server"
  namespace        = "kube-system"
  version          = "3.12.1"
  create_namespace = false

  set {
    name  = "args[0]"
    value = "--kubelet-insecure-tls"
  }
}

# 2. Ingress NGINX Controller
resource "helm_release" "ingress_nginx" {
  name             = "ingress-nginx"
  repository       = "https://kubernetes-github-pages.github.io/ingress-nginx"
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

  # Opcionális: Alapértelmezett Ingress vagy NodePort beállítások
  set {
    name  = "server.service.type"
    value = "ClusterIP"
  }

  depends_on = [
    helm_release.ingress_nginx
  ]
}