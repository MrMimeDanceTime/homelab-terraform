# One-time re-import of the NFS storage VMs. bpg only tracks the disks of a
# cloned VM that are already in state, so the scsi1 disk root attached after
# #64 never showed up. Both VMs were dropped from state with `tofu state rm`;
# importing reads every disk, scsi1 included.
#
# Delete this file once it has applied.

import {
  for_each = var.storage_vms
  to       = module.storage_vms[each.key].proxmox_virtual_environment_vm.vm
  id       = "${each.value.home_name}/${each.value.vm_id}"
}
