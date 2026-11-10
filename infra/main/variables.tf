variable "region" {
  description = "AWS region (Frankfurt, closest to Berlin)"
  type        = string
  default     = "eu-central-1"
}

variable "instance_type" {
  description = "EC2 instance type for the single-node k3s cluster"
  type        = string
  default     = "t3.small"
}

variable "ssh_public_key_path" {
  description = "Path to the SSH public key used to log into the instance"
  type        = string
  default     = "~/.ssh/gitops-aws.pub"
}

variable "repo_url" {
  description = "Git repository ArgoCD deploys from"
  type        = string
  default     = "https://github.com/Wafa358/gitops-platform.git"
}

variable "vpc_cidr" {
  type    = string
  default = "10.20.0.0/16"
}

variable "public_subnet_cidr" {
  type    = string
  default = "10.20.1.0/24"
}
