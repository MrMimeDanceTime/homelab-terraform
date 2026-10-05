resource "proxmox_virtual_environment_vm" "vm" {
  name        = var.name
  node_name   = var.target_node
  vm_id       = var.vm_id
  description = "Managed by Terraform."

  machine       = var.machine_type
  scsi_hardware = "virtio-scsi-single"
  on_boot       = true
  started       = true

  # These are pets. A change that needs a reboot should fail the apply, not
  # power-cycle the VM (mediadocker runs the CI runner doing the apply).
  reboot_after_update = false

  clone {
    vm_id     = var.template_vm_id
    node_name = var.template_node
    full      = true
  }

  agent {
    enabled = true
  }

  operating_system {
    type = "l26"
  }

  cpu {
    cores   = var.cpu_cores
    sockets = 1
    type    = "host"
    numa    = false
  }

  memory {
    dedicated = var.memory
    floating  = var.balloon # 0 disables the balloon device
  }

  disk {
    interface    = "scsi0"
    datastore_id = var.disk_storage
    size         = var.disk_size
    cache        = "none"
    discard      = "on"
    ssd          = true
    iothread     = true
    backup       = true
    replicate    = true
  }

  # Raw host disk for the Gluster VMs. PVE only lets root@pam attach these,
  # so creating a storage VM or changing this disk is a manual root operation.
  dynamic "disk" {
    for_each = var.passthrough_disk != null ? [var.passthrough_disk] : []
    content {
      interface         = "scsi1"
      datastore_id      = ""
      path_in_datastore = disk.value
      size              = var.passthrough_disk_size
      backup            = true # matches today; vzdump of a 12 TB raw disk is probably unwanted
      replicate         = false
    }
  }

  network_device {
    bridge = var.network_bridge
    model  = "virtio"
  }

  dynamic "hostpci" {
    for_each = var.gpu_passthrough != null ? [var.gpu_passthrough] : []
    content {
      device  = "hostpci0"
      mapping = hostpci.value.mapping_id
      pcie    = hostpci.value.pcie
      rombar  = hostpci.value.rombar
      xvga    = hostpci.value.primary_gpu
    }
  }

  initialization {
    datastore_id = var.cloudinit_storage
    interface    = "ide2"

    ip_config {
      ipv4 {
        address = "dhcp"
      }
    }

    user_account {
      username = var.ciuser
      password = var.cipassword
      keys     = [trimspace(var.sshkeys)]
    }
  }

  lifecycle {
    ignore_changes = [
      # Every clone attribute is ForceNew, and imported VMs have no clone
      # recorded. It only matters at creation anyway.
      clone,
      # Cloud-init is consumed on first boot only, so drift here is expected.
      # Rotating ssh_key_pub in Infisical does NOT reach existing VMs.
      initialization,
    ]
  }
}
