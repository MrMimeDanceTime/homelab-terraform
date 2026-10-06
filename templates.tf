# ============================================================================
# VM templates
# ============================================================================
# Images come from MrMimeDanceTime/homelab-images: official Debian cloud
# images with qemu-guest-agent baked in, published with a SHA-512 and a
# signed provenance attestation. To move to a newer image, change the tag and
# digest below in a PR; the plan replaces the downloaded file and the template.
# Existing VMs are full clones, so replacing the template never touches them.

locals {
  debian_13_image = {
    tag    = "debian-13-pve-20261001-2618-20261006"
    sha512 = "3cf9faab5f08d7842880e5c74cc6aec67f99747f7f16efe8cbc0e88d1ce118969b0356f755a98b057db801a53d9cd44d38f03627edc3c46e9a43a0d256b82c5e"
  }

  # Templates live on shared Ceph, so one copy serves every node. The image
  # only needs to land on one node's local storage to be imported.
  template_node      = "zeus"
  template_datastore = "ssd"
}

resource "proxmox_download_file" "debian_13" {
  node_name          = local.template_node
  datastore_id       = "local"
  content_type       = "import"
  url                = "https://github.com/MrMimeDanceTime/homelab-images/releases/download/${local.debian_13_image.tag}/${local.debian_13_image.tag}.qcow2"
  file_name          = "${local.debian_13_image.tag}.qcow2"
  checksum           = local.debian_13_image.sha512
  checksum_algorithm = "sha512"
}

resource "proxmox_virtual_environment_vm" "debian_13_template" {
  name        = "debian-13"
  description = "Debian 13 from ${local.debian_13_image.tag}. Managed by Terraform."
  node_name   = local.template_node
  template    = true
  started     = false
  on_boot     = false

  scsi_hardware = "virtio-scsi-single"

  agent {
    enabled = true
  }

  operating_system {
    type = "l26"
  }

  cpu {
    cores = 2
    type  = "host"
  }

  memory {
    dedicated = 2048
  }

  disk {
    interface    = "scsi0"
    datastore_id = local.template_datastore
    # import_from goes through the PVE API. file_id would import over SSH to
    # the node, which CI has no key for. Needs `import` content on `local`.
    import_from = proxmox_download_file.debian_13.id
    size        = 3 # the image's virtual size; clones grow it
    cache       = "none"
    discard     = "on"
    ssd         = true
    iothread    = true
  }

  network_device {
    bridge = local.default_network_bridge
    model  = "virtio"
  }

  initialization {
    datastore_id = local.template_datastore
    interface    = "ide2"

    ip_config {
      ipv4 {
        address = "dhcp"
      }
    }
  }
}
