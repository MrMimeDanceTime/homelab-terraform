# ============================================================================
# General Purpose VMs
# ============================================================================

module "vms" {
  source   = "./modules/proxmox-vm"
  for_each = var.vms

  # Core configuration
  name          = each.key
  target_node   = each.value.home_name
  vm_id         = each.value.vm_id
  template_name = each.value.template_name

  # Resources
  cpu_cores = each.value.cpu_cores
  memory    = each.value.memory
  balloon   = each.value.balloon
  disk_size = each.value.disk_size

  # Storage
  disk_storage      = local.default_disk_storage
  cloudinit_storage = local.default_cloudinit_storage

  # Network
  network_bridge = local.default_network_bridge

  # Cloud-init
  ciuser     = local.default_ciuser
  cipassword = data.infisical_secrets.hidden.secrets["ci_password"].value
  sshkeys    = data.infisical_secrets.visible.secrets["ssh_key_pub"].value
}

# ============================================================================
# Storage VMs (GlusterFS with disk passthrough)
# ============================================================================

module "storage_vms" {
  source   = "./modules/proxmox-vm"
  for_each = var.storage_vms

  # Core configuration
  name          = each.key
  target_node   = each.value.home_name
  vm_id         = each.value.vm_id
  template_name = each.value.template_name

  # Resources
  cpu_cores = each.value.cpu_cores
  memory    = each.value.memory
  balloon   = each.value.balloon
  disk_size = each.value.disk_size

  # Storage
  disk_storage      = local.default_disk_storage
  cloudinit_storage = local.default_cloudinit_storage
  passthrough_disk  = each.value.drive_id # Additional disk passthrough

  # Network (uses storage network bridge)
  network_bridge = local.storage_network_bridge

  # Cloud-init
  ciuser     = local.default_ciuser
  cipassword = data.infisical_secrets.hidden.secrets["ci_password"].value
  sshkeys    = data.infisical_secrets.visible.secrets["ssh_key_pub"].value
}

# ============================================================================
# Jellyfin VMs (with GPU passthrough)
# ============================================================================

module "jellyfin_vms" {
  source   = "./modules/proxmox-vm"
  for_each = var.jellyfin_vms

  # Core configuration
  name          = each.key
  target_node   = each.value.home_name
  vm_id         = each.value.vm_id
  template_name = each.value.template_name
  machine_type  = "q35" # Required for PCIe passthrough

  # Resources
  cpu_cores = each.value.cpu_cores
  memory    = each.value.memory
  balloon   = each.value.balloon
  disk_size = each.value.disk_size

  # Storage
  disk_storage      = local.default_disk_storage
  cloudinit_storage = local.default_cloudinit_storage

  # Network
  network_bridge = local.default_network_bridge

  # GPU passthrough
  gpu_passthrough = local.igpu_passthrough

  # Cloud-init
  ciuser     = local.default_ciuser
  cipassword = data.infisical_secrets.hidden.secrets["ci_password"].value
  sshkeys    = data.infisical_secrets.visible.secrets["ssh_key_pub"].value
}

# ============================================================================
# Miscellaneous VMs
# ============================================================================

module "misc_vms" {
  source   = "./modules/proxmox-vm"
  for_each = var.misc_vms

  # Core configuration
  name          = each.key
  target_node   = each.value.home_name
  vm_id         = each.value.vm_id
  template_name = each.value.template_name
  machine_type  = "q35" # Q35 machine type

  # Resources
  cpu_cores = each.value.cpu_cores
  memory    = each.value.memory
  balloon   = each.value.balloon
  disk_size = each.value.disk_size

  # Storage
  disk_storage      = local.default_disk_storage
  cloudinit_storage = local.default_cloudinit_storage

  # Network
  network_bridge = local.default_network_bridge

  # Cloud-init
  ciuser     = local.default_ciuser
  cipassword = data.infisical_secrets.hidden.secrets["ci_password"].value
  sshkeys    = data.infisical_secrets.visible.secrets["ssh_key_pub"].value
}
