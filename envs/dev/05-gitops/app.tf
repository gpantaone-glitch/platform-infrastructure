resource "kubectl_manifest" "argocd_root_app" {
  yaml_body = <<YAML
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: dev-root
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/gpantaone-glitch/platform-workload.git
    targetRevision: main
    path: argocd/dev
  destination:
    server: https://kubernetes.default.svc
    namespace: argocd
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
YAML

  depends_on = [
    helm_release.argocd,
    kubernetes_namespace.tns
  ]
}
