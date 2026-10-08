# ArgoCD Application managing Karpenter CRs from GitOps
# cascade delete finalizer ensures clean teardown
resource "kubectl_manifest" "karpenter_argocd_app" {
  yaml_body = yamlencode({
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "Application"
    metadata = {
      name      = "karpenter-resources"
      namespace = "argocd"
      finalizers = ["resources-finalizer.argocd.argoproj.io"]
      annotations = {
        "argocd.argoproj.io/sync-wave" = "1"
      }
    }
    spec = {
      project = "default"
      source = {
        repoURL        = var.gitops_repo_url
        targetRevision = var.gitops_repo_revision
        path           = "gitops/platform/karpenter"
      }
      destination = {
        server    = "https://kubernetes.default.svc"
        namespace = "default"
      }
      syncPolicy = {
        automated = {
          prune    = false # NEVER auto-prune Karpenter CRs
          selfHeal = true
        }
        syncOptions = ["CreateNamespace=false"]
      }
      ignoreDifferences = [
        {
          group = "karpenter.k8s.aws"
          kind  = "EC2NodeClass"
          jsonPointers = [
            "/spec/metadataOptions",
            "/spec/kubelet"
          ]
        }
      ]
    }
  })

  depends_on = [
    helm_release.karpenter,
    helm_release.argocd,
  ]
}

# Destroy-time provisioner: ensures clean teardown ordering
# Terraform destroy order (reverse of depends_on):
#   1. karpenter_cr_cleanup runs (deletes NodePool + EC2NodeClass, waits for finalizers)
#   2. karpenter_argocd_app is deleted
#   3. helm_release.karpenter is uninstalled (Karpenter controller stops)
resource "terraform_data" "karpenter_cr_cleanup" {
  triggers_replace = [helm_release.karpenter.id]

  provisioner "local-exec" {
    when        = destroy
    interpreter = ["/bin/bash", "-c"]
    command     = <<-EOT
      set -e
      echo "==> [Karpenter Cleanup] Deleting NodePool..."
      kubectl delete nodepool default --ignore-not-found --wait=true --timeout=45s || true

      echo "==> [Karpenter Cleanup] Deleting EC2NodeClass (finalizer processed by Karpenter controller)..."
      kubectl delete ec2nodeclass default --ignore-not-found --wait=true --timeout=60s || \
        kubectl patch ec2nodeclass default -p '{"metadata":{"finalizers":null}}' --type=merge 2>/dev/null || true

      echo "==> [Karpenter Cleanup] Complete."
    EOT
  }

  depends_on = [kubectl_manifest.karpenter_argocd_app]
}