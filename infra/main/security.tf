# Only MY current public IP may reach SSH and the Kubernetes API.
# The demo app (HTTP 80) is public.

data "http" "my_ip" {
  url = "https://checkip.amazonaws.com"
}

locals {
  my_ip_cidr = "${chomp(data.http.my_ip.response_body)}/32"
}

resource "aws_security_group" "k3s" {
  name        = "gitops-platform-k3s"
  description = "k3s node: SSH and Kubernetes API from my IP, HTTP from anywhere"
  vpc_id      = aws_vpc.main.id
}

resource "aws_vpc_security_group_ingress_rule" "ssh" {
  security_group_id = aws_security_group.k3s.id
  description       = "SSH from my IP"
  cidr_ipv4         = local.my_ip_cidr
  ip_protocol       = "tcp"
  from_port         = 22
  to_port           = 22
}

resource "aws_vpc_security_group_ingress_rule" "kube_api" {
  security_group_id = aws_security_group.k3s.id
  description       = "Kubernetes API from my IP"
  cidr_ipv4         = local.my_ip_cidr
  ip_protocol       = "tcp"
  from_port         = 6443
  to_port           = 6443
}

resource "aws_vpc_security_group_ingress_rule" "http" {
  security_group_id = aws_security_group.k3s.id
  description       = "Public HTTP for the demo app (Traefik ingress)"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
  from_port         = 80
  to_port           = 80
}

resource "aws_vpc_security_group_egress_rule" "all" {
  security_group_id = aws_security_group.k3s.id
  description       = "Outbound internet (packages, images, GitHub)"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}
