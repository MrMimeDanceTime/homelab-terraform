# One-time move from Telmate's proxmox_vm_qemu to bpg's
# proxmox_virtual_environment_vm. Nothing is created or destroyed: the old
# state entries are forgotten and the same VMs are imported under the new type.
# Delete this file (and the telmate provider) once it has applied.

removed {
  from = module.vms.proxmox_vm_qemu.vm
  lifecycle {
    destroy = false
  }
}

removed {
  from = module.storage_vms.proxmox_vm_qemu.vm
  lifecycle {
    destroy = false
  }
}

removed {
  from = module.jellyfin_vms.proxmox_vm_qemu.vm
  lifecycle {
    destroy = false
  }
}

removed {
  from = module.misc_vms.proxmox_vm_qemu.vm
  lifecycle {
    destroy = false
  }
}

import {
  for_each = var.vms
  to       = module.vms[each.key].proxmox_virtual_environment_vm.vm
  id       = "${each.value.home_name}/${each.value.vm_id}"
}

import {
  for_each = var.storage_vms
  to       = module.storage_vms[each.key].proxmox_virtual_environment_vm.vm
  id       = "${each.value.home_name}/${each.value.vm_id}"
}

import {
  for_each = var.jellyfin_vms
  to       = module.jellyfin_vms[each.key].proxmox_virtual_environment_vm.vm
  id       = "${each.value.home_name}/${each.value.vm_id}"
}

import {
  for_each = var.misc_vms
  to       = module.misc_vms[each.key].proxmox_virtual_environment_vm.vm
  id       = "${each.value.home_name}/${each.value.vm_id}"
}
