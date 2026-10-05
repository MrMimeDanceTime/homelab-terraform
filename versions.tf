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
      source  = "bpg/proxmox"
      version = "~> 0.115.0"
    }
    # Only so migration.tf can forget the old proxmox_vm_qemu state entries.
    # Remove together with migration.tf once the bpg import has applied.
    telmate = {
      source  = "Telmate/proxmox"
      version = "3.0.2-rc10"
    }
    infisical = {
      source  = "infisical/infisical"
      version = "~> 0.19"
    }
  }
}
