# Resource Move Declarations
# These tell Terraform that resources were refactored into modules
# This prevents destroy/recreate during the migration

# General VMs - moved from direct resources to module
moved {
  from = proxmox_vm_qemu.clone_vms["vm1"]
  to   = module.vms["vm1"].proxmox_vm_qemu.vm
}

moved {
  from = proxmox_vm_qemu.clone_vms["minecraft-server"]
  to   = module.vms["minecraft-server"].proxmox_vm_qemu.vm
}

# Jellyfin VMs - moved to module
moved {
  from = proxmox_vm_qemu.jellyfin_vms["mediadocker"]
  to   = module.jellyfin_vms["mediadocker"].proxmox_vm_qemu.vm
}

# Storage VMs - moved to module
moved {
  from = proxmox_vm_qemu.storage_vms["gluster-hades"]
  to   = module.storage_vms["gluster-hades"].proxmox_vm_qemu.vm
}

moved {
  from = proxmox_vm_qemu.storage_vms["gluster-poseidon"]
  to   = module.storage_vms["gluster-poseidon"].proxmox_vm_qemu.vm
}

# Misc VMs - moved to module
moved {
  from = proxmox_vm_qemu.misc_vms["gamewings"]
  to   = module.misc_vms["gamewings"].proxmox_vm_qemu.vm
}
