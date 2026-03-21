resource "kubernetes_manifest" "sample_app" {
  manifest = {
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "Application"

    metadata = {
      name      = "tns"
      namespace = "argocd"
    }

    spec = {
      project = "default"

      source = {
        repoURL        = "https://github.com/gpantaone-glitch/platform-workload.git"
        targetRevision = "main"
        path           = "argocd/dev"
      }

      destination = {
        server    = "https://kubernetes.default.svc"
        namespace = "tns"
      }

      syncPolicy = {
        automated = {
          prune    = true
          selfHeal = true
        }
      }
    }
  }
}
