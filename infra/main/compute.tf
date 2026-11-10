# Ubuntu 24.04 LTS, latest official image from Canonical
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }
  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}

resource "aws_key_pair" "main" {
  key_name   = "gitops-platform"
  public_key = file(pathexpand(var.ssh_public_key_path))
}

resource "aws_instance" "k3s" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.k3s.id]
  key_name               = aws_key_pair.main.key_name

  # Installs k3s + ArgoCD and points ArgoCD at this Git repo (see user-data.sh.tftpl)
  user_data = templatefile("${path.module}/user-data.sh.tftpl", {
    repo_url = var.repo_url
  })
  user_data_replace_on_change = true

  root_block_device {
    volume_size = 20
    volume_type = "gp3"
    encrypted   = true
  }

  metadata_options {
    http_tokens = "required" # IMDSv2 only
  }

  tags = {
    Name = "gitops-platform-k3s"
  }
}
