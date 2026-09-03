resource "proxmox_vm_qemu" "vm" {
  name        = var.name
  target_node = var.target_node
  vmid        = var.vm_id
  clone       = var.template_name
  agent       = 1
  os_type     = "cloud-init"
  machine     = var.machine_type
  memory      = var.memory
  balloon     = var.balloon
  scsihw      = "virtio-scsi-single"
  onboot      = true
  full_clone  = true

  cpu {
    cores   = var.cpu_cores
    sockets = 1
    type    = "host"
    numa    = false
  }

  disks {
    ide {
      ide2 {
        cloudinit {
          storage = var.cloudinit_storage
        }
      }
    }

    scsi {
      # Primary disk (scsi0)
      scsi0 {
        disk {
          backup             = true
          cache              = "none"
          discard            = true
          emulatessd         = true
          iothread           = true
          mbps_r_burst       = 0.0
          mbps_r_concurrent  = 0.0
          mbps_wr_burst      = 0.0
          mbps_wr_concurrent = 0.0
          replicate          = true
          size               = var.disk_size
          storage            = var.disk_storage
        }
      }

      # Optional: Passthrough disk (scsi1) for storage VMs
      dynamic "scsi1" {
        for_each = var.passthrough_disk != null ? [1] : []
        content {
          passthrough {
            file = var.passthrough_disk
          }
        }
      }
    }
  }

  network {
    id     = 0
    model  = "virtio"
    bridge = var.network_bridge
  }

  # Optional: GPU passthrough for Jellyfin VMs
  dynamic "pci" {
    for_each = var.gpu_passthrough != null ? [var.gpu_passthrough] : []
    content {
      id          = 0
      mapping_id  = pci.value.mapping_id
      rombar      = pci.value.rombar
      pcie        = pci.value.pcie
      primary_gpu = pci.value.primary_gpu
      vendor_id   = pci.value.vendor_id
    }
  }

  # Cloud-init configuration
  ipconfig0  = "ip=dhcp"
  ciuser     = var.ciuser
  cipassword = var.cipassword
  sshkeys    = var.sshkeys

  # Cloud-init values are only consumed on first boot, so drift here is
  # expected. This also means rotating ssh_key_pub in Infisical does NOT
  # propagate to existing VMs; push new keys through cloud-init or SSH.
  lifecycle {
    ignore_changes = [
      sshkeys,
      ipconfig0,
    ]
  }
}
