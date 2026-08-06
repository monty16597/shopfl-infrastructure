terraform {
  # State lives in a shared bucket in ca-central-1; the resources themselves are
  # in us-east-1. The backend region is independent of the provider region.
  backend "s3" {
    bucket       = "devops-project-terraform-remote-backend"
    key          = "shopfl/dev/terraform.tfstate"
    region       = "ca-central-1"
    encrypt      = true
    use_lockfile = true
  }
}
