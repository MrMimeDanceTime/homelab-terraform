# Core VM Configuration
variable "name" {
  description = "VM name"
  type        = string
}

variable "target_node" {
  description = "Proxmox node to deploy VM on"
  type        = string
}

variable "vm_id" {
  description = "Proxmox VM ID"
  type        = number
  default     = null
}

variable "template_vm_id" {
  description = "VM ID of the template to clone"
  type        = number
}

variable "template_node" {
  description = "Node the template lives on"
  type        = string
}

# CPU & Memory Configuration
variable "cpu_cores" {
  description = "Number of CPU cores"
  type        = number
}

variable "memory" {
  description = "Memory in MB"
  type        = number
}

variable "balloon" {
  description = "Memory ballooning minimum in MB"
  type        = number
}

# Disk Configuration
variable "disk_size" {
  description = "Primary disk size in GB"
  type        = number
}

variable "disk_storage" {
  description = "Storage location for VM disks"
  type        = string
}

variable "cloudinit_storage" {
  description = "Storage location for cloud-init drive"
  type        = string
}

# Optional: Additional disk passthrough (for storage VMs)
variable "passthrough_disk_size" {
  description = "Size in GB of the passthrough disk, as PVE reports it. Must match, or the plan shows a resize."
  type        = number
  default     = null
}

variable "passthrough_disk" {
  description = "Optional disk passthrough device path (e.g., /dev/disk/by-id/...)"
  type        = string
  default     = null
}

# Network Configuration
variable "network_bridge" {
  description = "Network bridge to use"
  type        = string
}

# Cloud-init Configuration
variable "ciuser" {
  description = "Cloud-init username"
  type        = string
}

variable "cipassword" {
  description = "Cloud-init user password"
  type        = string
  sensitive   = true
}

variable "sshkeys" {
  description = "SSH public keys for cloud-init user"
  type        = string
}

# Optional: GPU Passthrough (for Jellyfin VMs)
variable "gpu_passthrough" {
  description = "GPU passthrough configuration"
  type = object({
    mapping_id  = string
    rombar      = bool
    pcie        = bool
    primary_gpu = bool
  })
  default = null
}

# Optional: Machine Type
variable "machine_type" {
  description = "QEMU machine type (e.g., 'q35' for PCIe support)"
  type        = string
  default     = null
}
