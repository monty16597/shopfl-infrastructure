terraform {
  # Lowered from 1.10 to 1.9 for compatibility with Terraform 1.9.x
  # Note: S3 native state locking (use_lockfile) requires 1.10+
  required_version = ">= 1.9"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.4"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}
