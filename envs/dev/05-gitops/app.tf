resource "kubernetes_manifest" "sample_app" {
  manifest = {
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "Application"

    metadata = {
      name      = "sample-app"
      namespace = "argocd"
    }

    spec = {
      project = "default"

      source = {
        repoURL        = "https://github.com/gpantaone-glitch/platform-workload.git"
        targetRevision = "main"
        path           = "k8s"
      }

      destination = {
        server    = "https://kubernetes.default.svc"
        namespace = "sample"
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
