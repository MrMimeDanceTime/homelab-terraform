# ============================================================================
# Proxmox Configuration Variables
# ============================================================================

variable "proxmox_api_url" {
  description = "Proxmox API URL (e.g., https://proxmox.example:8006/api2/json)"
  type        = string
}

variable "proxmox_user" {
  description = "Proxmox user for authentication"
  type        = string
  default     = "root@pam"
}

variable "proxmox_tls_insecure" {
  description = "Skip TLS verification of the Proxmox API certificate. Set explicitly in terraform.tfvars."
  type        = bool
  default     = false
}

# ============================================================================
# Infisical Configuration Variables
# ============================================================================

variable "infisical_client_id" {
  description = "Infisical Machine Identity Client ID"
  type        = string
  sensitive   = true
}

variable "infisical_client_secret" {
  description = "Infisical Machine Identity Client Secret"
  type        = string
  sensitive   = true
}

variable "infisical_workspace_id" {
  description = "Infisical workspace ID"
  type        = string
}

variable "infisical_env" {
  description = "Infisical environment (e.g., prod, dev)"
  type        = string
  default     = "prod"
}

# ============================================================================
# VM Configuration Maps
# ============================================================================

variable "vms" {
  description = "Map of general-purpose VM configurations"
  type = map(object({
    home_name     = string
    vm_id         = number
    cpu_cores     = number
    memory        = number
    balloon       = number
    disk_size     = number
    template_name = string
  }))
  default = {}
}

variable "jellyfin_vms" {
  description = "Map of Jellyfin media server VM configurations (with GPU passthrough)"
  type = map(object({
    home_name     = string
    vm_id         = number
    cpu_cores     = number
    memory        = number
    balloon       = number
    disk_size     = number
    template_name = string
  }))
  default = {}
}

variable "storage_vms" {
  description = "Map of GlusterFS storage VM configurations (with disk passthrough)"
  type = map(object({
    home_name     = string
    vm_id         = number
    cpu_cores     = number
    memory        = number
    balloon       = number
    disk_size     = number
    template_name = string
    drive_id      = string
  }))
  default = {}
}

variable "misc_vms" {
  description = "Map of miscellaneous VM configurations"
  type = map(object({
    home_name     = string
    vm_id         = number
    cpu_cores     = number
    memory        = number
    balloon       = number
    disk_size     = number
    template_name = string
  }))
  default = {}
}
