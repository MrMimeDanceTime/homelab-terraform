output "id" {
  description = "Proxmox VM ID"
  value       = proxmox_virtual_environment_vm.vm.id
}

output "name" {
  description = "VM name"
  value       = proxmox_virtual_environment_vm.vm.name
}

# ipv4_addresses is one list per interface as reported by the guest agent;
# the first interface is loopback.
output "default_ipv4_address" {
  description = "Default IPv4 address of the VM"
  value = try([
    for ips in proxmox_virtual_environment_vm.vm.ipv4_addresses : ips[0]
    if length(ips) > 0 && ips[0] != "127.0.0.1"
  ][0], null)
}

output "ssh_host" {
  description = "SSH host (IP address)"
  value = try([
    for ips in proxmox_virtual_environment_vm.vm.ipv4_addresses : ips[0]
    if length(ips) > 0 && ips[0] != "127.0.0.1"
  ][0], null)
}

output "vmid" {
  description = "Proxmox VM ID (numeric)"
  value       = proxmox_virtual_environment_vm.vm.vm_id
}
