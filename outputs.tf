# ============================================================================
# VM Outputs
# ============================================================================
# Note: Actual values are stored in encrypted state file, not in this file.
# These output definitions only specify WHAT to output, not the values themselves.
# Mark sensitive outputs to prevent display in CLI/logs.

# General Purpose VMs
output "vms" {
  description = "General purpose VM information"
  value = {
    for k, v in module.vms : k => {
      id                   = v.id
      vmid                 = v.vmid
      name                 = v.name
      default_ipv4_address = v.default_ipv4_address
      ssh_host             = v.ssh_host
    }
  }
  sensitive = true
}

# Storage VMs
output "storage_vms" {
  description = "Storage VM information"
  value = {
    for k, v in module.storage_vms : k => {
      id                   = v.id
      vmid                 = v.vmid
      name                 = v.name
      default_ipv4_address = v.default_ipv4_address
      ssh_host             = v.ssh_host
    }
  }
  sensitive = true
}

# Jellyfin VMs
output "jellyfin_vms" {
  description = "Jellyfin VM information"
  value = {
    for k, v in module.jellyfin_vms : k => {
      id                   = v.id
      vmid                 = v.vmid
      name                 = v.name
      default_ipv4_address = v.default_ipv4_address
      ssh_host             = v.ssh_host
    }
  }
  sensitive = true
}

# Miscellaneous VMs
output "misc_vms" {
  description = "Miscellaneous VM information"
  value = {
    for k, v in module.misc_vms : k => {
      id                   = v.id
      vmid                 = v.vmid
      name                 = v.name
      default_ipv4_address = v.default_ipv4_address
      ssh_host             = v.ssh_host
    }
  }
  sensitive = true
}

# Summary output (non-sensitive - just counts)
output "vm_summary" {
  description = "Summary of managed VMs (counts only)"
  value = {
    total_vms    = length(module.vms) + length(module.storage_vms) + length(module.jellyfin_vms) + length(module.misc_vms)
    general_vms  = length(module.vms)
    storage_vms  = length(module.storage_vms)
    jellyfin_vms = length(module.jellyfin_vms)
    misc_vms     = length(module.misc_vms)
  }
}
