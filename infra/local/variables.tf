variable "cluster_name" {
  type    = string
  default = "gitops"
}

variable "repo_url" {
  description = "Git repository ArgoCD deploys from"
  type        = string
  default     = "https://github.com/Wafa358/gitops-platform.git"
}

# Pin exact chart versions - find them with:
#   helm repo add argo https://argoproj.github.io/argo-helm
#   helm search repo argo/argo-cd
#   helm search repo argo/argocd-apps
variable "argocd_chart_version" {
  type    = string
  default = "10.17.1"
}

variable "argocd_apps_chart_version" {
  type    = string
  default = "2.0.8"
}

variable "argocd_host_port" {
  description = "Port on your PC where the ArgoCD UI is published (https://localhost:<port>)"
  type        = number
  default     = 8443
}
