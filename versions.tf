terraform {
  required_version = ">= 1.8.0"

  backend "s3" {
    bucket         = "mac-iac-tfstate"
    dynamodb_table = "mac-iac-tfstate-lock"
    region         = "us-west-2"
    encrypt        = true
    # key is set per-environment via -backend-config in CI
  }

  required_providers {
    proxmox = {
      source  = "Telmate/proxmox"
      version = "3.0.1-rc9"
    }
    infisical = {
      source  = "infisical/infisical"
      version = "~> 0.19"
    }
  }
}
