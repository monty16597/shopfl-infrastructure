terraform {
  # 1.9 is the floor for compatibility with the validation environment.
  # S3 native state locking (use_lockfile in backend.tf) requires 1.10+
  # but validation can proceed with 1.9.x.
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
