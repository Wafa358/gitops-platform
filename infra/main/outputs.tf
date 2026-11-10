output "public_ip" {
  value = aws_instance.k3s.public_ip
}

output "app_url" {
  value = "http://${aws_instance.k3s.public_ip}/health"
}

output "ssh_command" {
  value = "ssh -i ~/.ssh/gitops-aws ubuntu@${aws_instance.k3s.public_ip}"
}

output "kubeconfig_command" {
  description = "Copies the cluster kubeconfig to your machine"
  value       = "scp -i ~/.ssh/gitops-aws ubuntu@${aws_instance.k3s.public_ip}:/etc/rancher/k3s/k3s.yaml ./kubeconfig-aws"
}
