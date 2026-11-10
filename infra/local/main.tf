# The whole local platform as code:
#   terraform apply   -> kind cluster + ArgoCD + root "platform" Application
#   terraform destroy -> everything gone
# Everything else (task-api, monitoring) is then deployed by ArgoCD from Git.

# 1. Kubernetes cluster (kind = Kubernetes in Docker)
resource "kind_cluster" "this" {
  name           = var.cluster_name
  wait_for_ready = true

  kind_config {
    kind        = "Cluster"
    api_version = "kind.x-k8s.io/v1alpha4"

    node {
      role = "control-plane"

      # Publish the ArgoCD UI on the host: no port-forward needed
      extra_port_mappings {
        container_port = 30443
        host_port      = var.argocd_host_port
      }
    }
  }
}

# 2. ArgoCD, from its official Helm chart
resource "helm_release" "argocd" {
  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  version          = var.argocd_chart_version
  namespace        = "argocd"
  create_namespace = true
  wait             = true
  timeout          = 600

  values = [yamlencode({
    server = {
      service = {
        type          = "NodePort"
        nodePortHttps = 30443
      }
    }
    # Dex (SSO) is not needed locally - saves memory
    dex = {
      enabled = false
    }
  })]
}

# 3. "App of apps": one root Application that deploys every Application
#    defined in k8s/argocd/ (task-api, monitoring). Git stays the source of truth.
resource "helm_release" "root_app" {
  name       = "platform"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argocd-apps"
  version    = var.argocd_apps_chart_version
  namespace  = "argocd"

  values = [yamlencode({
    applications = {
      platform = {
        namespace = "argocd"
        project   = "default"
        source = {
          repoURL        = var.repo_url
          targetRevision = "main"
          path           = "k8s/argocd"
        }
        destination = {
          server    = "https://kubernetes.default.svc"
          namespace = "argocd"
        }
        syncPolicy = {
          automated = {
            prune    = true
            selfHeal = true
          }
        }
      }
    }
  })]

  depends_on = [helm_release.argocd]
}
