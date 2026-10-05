terraform {
  required_version = ">= 1.8.0"

  required_providers {
    proxmox = {
      source = "bpg/proxmox"
      # Version is pinned once, in the root module's versions.tf.
    }
  }
}
