output "argocd_url" {
  value = "https://localhost:${var.argocd_host_port}"
}

output "argocd_password_command" {
  description = "PowerShell: prints the initial ArgoCD admin password"
  value       = "[Text.Encoding]::UTF8.GetString([Convert]::FromBase64String((kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}')))"
}

output "kubeconfig_command" {
  description = "Adds the cluster to your kubectl config"
  value       = "kind export kubeconfig --name ${var.cluster_name}"
}
