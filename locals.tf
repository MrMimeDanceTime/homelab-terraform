# Common configuration values used across all VMs
locals {
  # Storage locations
  default_disk_storage      = "local-lvm"
  default_cloudinit_storage = "local-lvm"

  # Network bridges
  default_network_bridge = "vmbr0"
  storage_network_bridge = "vmbr2"

  # Cloud-init user
  default_ciuser = "mrmimedancetime"

  # GPU passthrough configuration for Jellyfin VMs
  igpu_passthrough = {
    mapping_id  = "igpu"
    rombar      = true
    pcie        = true
    primary_gpu = false
    vendor_id   = "8086"
  }
}
