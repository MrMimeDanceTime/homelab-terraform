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
  }

  # ST12000VN0008 passthrough disks, as PVE reports their size.
  gluster_disk_size_gb = 11176

  # Template name -> {vm_id, node_name}, so tfvars can keep naming templates.
  templates = {
    for vm in data.proxmox_virtual_environment_vms.templates.vms : vm.name => vm
  }
}

data "proxmox_virtual_environment_vms" "templates" {
  filter {
    name   = "template"
    values = [true]
  }
}
