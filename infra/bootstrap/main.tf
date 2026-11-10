# Bootstrap: resources that must exist BEFORE the main stack.
#  - S3 bucket for the Terraform remote state (versioned, encrypted, private)
#  - A monthly budget alert so the AWS bill can never surprise us
# Run once with local state: terraform init && terraform apply

terraform {
  required_version = ">= 1.10"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.5"
    }
  }
}

variable "region" {
  type    = string
  default = "eu-central-1"
}

variable "budget_email" {
  description = "Email that receives the budget alerts"
  type        = string
}

variable "budget_limit_usd" {
  type    = string
  default = "5"
}

provider "aws" {
  region = var.region
  default_tags {
    tags = {
      Project   = "gitops-platform"
      ManagedBy = "terraform"
    }
  }
}

# Bucket names are global: add a random suffix
resource "random_id" "suffix" {
  byte_length = 4
}

resource "aws_s3_bucket" "tfstate" {
  bucket = "gitops-platform-tfstate-${random_id.suffix.hex}"
}

resource "aws_s3_bucket_versioning" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "tfstate" {
  bucket                  = aws_s3_bucket.tfstate.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_budgets_budget" "monthly" {
  name         = "gitops-platform-monthly"
  budget_type  = "COST"
  limit_amount = var.budget_limit_usd
  limit_unit   = "USD"
  time_unit    = "MONTHLY"

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 80
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = [var.budget_email]
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 100
    threshold_type             = "PERCENTAGE"
    notification_type          = "FORECASTED"
    subscriber_email_addresses = [var.budget_email]
  }
}

# Write the backend config for the main stack, so nobody has to copy the bucket name by hand
resource "local_file" "backend_config" {
  filename = "${path.module}/../main/backend.hcl"
  content  = <<-EOT
    bucket       = "${aws_s3_bucket.tfstate.bucket}"
    key          = "gitops-platform/terraform.tfstate"
    region       = "${var.region}"
    use_lockfile = true
    encrypt      = true
  EOT
}

output "state_bucket" {
  value = aws_s3_bucket.tfstate.bucket
}
