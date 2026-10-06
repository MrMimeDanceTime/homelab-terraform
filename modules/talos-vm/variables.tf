variable "name" {
  description = "VM name, also the Talos hostname"
  type        = string
}

variable "cluster_name" {
  description = "Cluster the node belongs to (used for tags and description)"
  type        = string
}

variable "target_node" {
  description = "Proxmox node to run the VM on"
  type        = string
}

variable "vm_id" {
  description = "Proxmox VM ID"
  type        = number
}

variable "cpu_cores" {
  description = "Number of CPU cores"
  type        = number
}

variable "memory" {
  description = "Memory in MB"
  type        = number
}

variable "disk_size" {
  description = "System disk size in GB"
  type        = number
}

variable "disk_storage" {
  description = "Datastore for the system disk and cloud-init drive"
  type        = string
}

variable "image_id" {
  description = "Talos disk image to import, as <storage>:import/<file> on the target node"
  type        = string
}

variable "network_bridge" {
  description = "Network bridge"
  type        = string
}

variable "ipv4_cidr" {
  description = "Static address in CIDR notation, e.g. 192.168.30.51/24"
  type        = string
}

variable "gateway" {
  description = "IPv4 default gateway"
  type        = string
}

variable "dns_servers" {
  description = "DNS servers"
  type        = list(string)
}

variable "generation" {
  description = "Cluster generation. Changing it replaces the VM (see talos.tf)."
  type        = number
}
