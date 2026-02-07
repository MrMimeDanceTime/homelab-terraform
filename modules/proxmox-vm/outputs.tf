output "id" {
  description = "Proxmox VM ID"
  value       = proxmox_vm_qemu.vm.id
}

output "name" {
  description = "VM name"
  value       = proxmox_vm_qemu.vm.name
}

output "default_ipv4_address" {
  description = "Default IPv4 address of the VM"
  value       = proxmox_vm_qemu.vm.default_ipv4_address
}

output "ssh_host" {
  description = "SSH host (IP address)"
  value       = proxmox_vm_qemu.vm.ssh_host
}

output "vmid" {
  description = "Proxmox VM ID (numeric)"
  value       = proxmox_vm_qemu.vm.vmid
}
