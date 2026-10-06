# A Talos node VM. Talos is configured by machine config through its own API,
# not cloud-init, so this module only builds the VM and hands Talos its static
# address through the Proxmox cloud-init drive, which the nocloud platform
# reads. Everything else is talos.tf's job.
resource "terraform_data" "generation" {
  input = var.generation
}

resource "proxmox_virtual_environment_vm" "vm" {
  name        = var.name
  node_name   = var.target_node
  vm_id       = var.vm_id
  description = "Talos node in ${var.cluster_name}. Managed by Terraform."
  tags        = ["talos", var.cluster_name]

  machine       = "q35"
  scsi_hardware = "virtio-scsi-single"
  on_boot       = true
  started       = true

  reboot_after_update = false

  agent {
    enabled = true
    # The address is static and known up front, and the agent extension may
    # not be running before Talos has its config. Nothing to wait for.
    wait_for_ip {
      disabled = true
    }
  }

  operating_system {
    type = "l26"
  }

  cpu {
    cores = var.cpu_cores
    type  = "host"
  }

  memory {
    dedicated = var.memory # no ballooning; Kubernetes schedules against this
  }

  disk {
    interface    = "scsi0"
    datastore_id = var.disk_storage
    import_from  = var.image_id
    size         = var.disk_size
    cache        = "none"
    discard      = "on"
    ssd          = true
    iothread     = true
  }

  network_device {
    bridge = var.network_bridge
    model  = "virtio"
  }

  initialization {
    datastore_id = var.disk_storage
    interface    = "ide2"

    ip_config {
      ipv4 {
        address = var.ipv4_cidr
        gateway = var.gateway
      }
    }

    dns {
      servers = var.dns_servers
    }
  }

  lifecycle {
    replace_triggered_by = [terraform_data.generation]
    ignore_changes = [
      # The disk image only matters at creation. Talos upgrades in place
      # through talos_machine.image, so a newer image must not rebuild nodes.
      disk[0].import_from,
    ]
  }
}
