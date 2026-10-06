# ============================================================================
# k8s-dev: Talos Kubernetes cluster (Stage 0)
# ============================================================================
# Three nodes, each control plane and worker, one per host so the cluster
# survives losing a host. Disposable by design: the wreck-it lab.
#
# Everything is Terraform: image, VMs, machine config, bootstrap. Upgrades
# are PRs too:
#   - Talos OS: bump local.talos.version (talos_machine.image follows)
#   - Kubernetes: bump local.talos.kubernetes_version (talos_cluster runs
#     upgrade-k8s with health gating)
# Leave config_contract alone on upgrades; it pins the machine config schema
# to the version the cluster was created with.

locals {
  talos = {
    cluster_name       = "k8s-dev"
    version            = "v1.14.2"
    config_contract    = "v1.14"
    kubernetes_version = "v1.37.1"

    vip         = "192.168.30.50" # Kubernetes API, held by one control plane at a time
    prefix      = 24
    gateway     = "192.168.30.1"
    dns_servers = ["192.168.30.1"]

    cpu_cores    = 4
    memory       = 8192
    disk_size    = 40
    disk_storage = "ssd"
  }

  talos_nodes = {
    "talos-dev-1" = { host = "hades", vm_id = 151, ip = "192.168.30.51" }
    "talos-dev-2" = { host = "poseidon", vm_id = 152, ip = "192.168.30.52" }
    "talos-dev-3" = { host = "zeus", vm_id = 153, ip = "192.168.30.53" }
  }

  talos_node_ips = [for n in local.talos_nodes : n.ip]
}

# ----------------------------------------------------------------------------
# Image: Talos nocloud with the QEMU guest agent extension
# ----------------------------------------------------------------------------

resource "talos_image_factory_schematic" "k8s_dev" {
  schematic = yamlencode({
    customization = {
      systemExtensions = {
        officialExtensions = ["siderolabs/qemu-guest-agent"]
      }
    }
  })
}

data "talos_image_factory_urls" "k8s_dev" {
  talos_version     = local.talos.version
  schematic_id      = talos_image_factory_schematic.k8s_dev.id
  platform          = "nocloud"
  disk_image_format = "qcow2" # uncompressed, so import_from works without SSH
}

# local is per node, so each host that runs a Talos VM gets its own copy.
resource "proxmox_download_file" "talos" {
  for_each = toset([for n in local.talos_nodes : n.host])

  node_name    = each.key
  datastore_id = "local"
  content_type = "import"
  url          = data.talos_image_factory_urls.k8s_dev.urls.disk_image
  file_name    = "talos-${local.talos.version}-${substr(talos_image_factory_schematic.k8s_dev.id, 0, 12)}-nocloud-amd64.qcow2"
}

# ----------------------------------------------------------------------------
# VMs
# ----------------------------------------------------------------------------

module "talos_vms" {
  source   = "./modules/talos-vm"
  for_each = local.talos_nodes

  name         = each.key
  cluster_name = local.talos.cluster_name
  target_node  = each.value.host
  vm_id        = each.value.vm_id

  cpu_cores    = local.talos.cpu_cores
  memory       = local.talos.memory
  disk_size    = local.talos.disk_size
  disk_storage = local.talos.disk_storage
  image_id     = proxmox_download_file.talos[each.value.host].id

  network_bridge = local.default_network_bridge
  ipv4_cidr      = "${each.value.ip}/${local.talos.prefix}"
  gateway        = local.talos.gateway
  dns_servers    = local.talos.dns_servers
}

# ----------------------------------------------------------------------------
# Talos configuration and bootstrap
# ----------------------------------------------------------------------------

resource "talos_machine_secrets" "k8s_dev" {
  talos_version = local.talos.config_contract
}

data "talos_machine_configuration" "k8s_dev" {
  for_each = local.talos_nodes

  cluster_name       = local.talos.cluster_name
  cluster_endpoint   = "https://${local.talos.vip}:6443"
  machine_type       = "controlplane"
  machine_secrets    = talos_machine_secrets.k8s_dev.machine_secrets
  talos_version      = local.talos.config_contract
  kubernetes_version = local.talos.kubernetes_version

  # The v1.14 contract generates new-style documents, so patches target those
  # documents rather than the old machine/cluster fields. Validated locally
  # with `talosctl validate --mode cloud` before shipping.
  config_patches = [
    # Our installer, so OS upgrades keep the qemu-guest-agent extension.
    yamlencode({
      apiVersion = "v1alpha1"
      kind       = "UnattendedInstallConfig"
      installer = {
        image = data.talos_image_factory_urls.k8s_dev.urls.installer
      }
      provisioning = {
        diskSelector = {
          match = "disk.dev_path == \"/dev/sda\""
        }
        wipe = false
      }
    }),
    # The generated document sets auto: stable, which conflicts with a fixed
    # hostname, so it is replaced rather than merged.
    yamlencode({
      apiVersion = "v1alpha1"
      kind       = "HostnameConfig"
      "$patch"   = "delete"
    }),
    yamlencode({
      apiVersion = "v1alpha1"
      kind       = "HostnameConfig"
      hostname   = each.key
    }),
    # Every node is also a worker: replace the generated document to drop the
    # control-plane NoSchedule taint, and the exclude-from-external-load-
    # balancers label so LoadBalancer services can use these nodes.
    yamlencode({
      apiVersion = "v1alpha1"
      kind       = "KubeNodeConfig"
      "$patch"   = "delete"
    }),
    yamlencode({
      apiVersion = "v1alpha1"
      kind       = "KubeNodeConfig"
      labels = {
        "node-role.kubernetes.io/control-plane" = ""
      }
    }),
    # Name the single virtio NIC so the VIP does not depend on how the
    # kernel names the interface.
    yamlencode({
      apiVersion = "v1alpha1"
      kind       = "LinkAliasConfig"
      name       = "net0"
      selector = {
        match = "link.driver == \"virtio_net\""
      }
    }),
    yamlencode({
      apiVersion = "v1alpha1"
      kind       = "Layer2VIPConfig"
      name       = local.talos.vip
      link       = "net0"
    }),
  ]
}

resource "talos_machine" "k8s_dev" {
  for_each   = local.talos_nodes
  depends_on = [module.talos_vms]

  node                  = each.value.ip
  client_configuration  = talos_machine_secrets.k8s_dev.client_configuration
  machine_configuration = data.talos_machine_configuration.k8s_dev[each.key].machine_configuration
  image                 = data.talos_image_factory_urls.k8s_dev.urls.installer

  # talos_cluster owns Kubernetes upgrades.
  ignore_kubernetes_upgrade_drift = true
  # Dev cluster: no drain on OS upgrades for now. Revisit before anything
  # stateful lands here; draining needs the kubeconfig wired in.
  drain_on_upgrade = false
}

resource "talos_cluster" "k8s_dev" {
  depends_on = [talos_machine.k8s_dev]

  node                 = local.talos_nodes["talos-dev-1"].ip
  control_plane_nodes  = local.talos_node_ips
  client_configuration = talos_machine_secrets.k8s_dev.client_configuration
  kubernetes_version   = local.talos.kubernetes_version
}

data "talos_client_configuration" "k8s_dev" {
  cluster_name         = local.talos.cluster_name
  client_configuration = talos_machine_secrets.k8s_dev.client_configuration
  endpoints            = local.talos_node_ips
  nodes                = local.talos_node_ips
}

resource "talos_cluster_kubeconfig" "k8s_dev" {
  depends_on = [talos_cluster.k8s_dev]

  client_configuration = talos_machine_secrets.k8s_dev.client_configuration
  node                 = local.talos_nodes["talos-dev-1"].ip
}

# Read with: tofu output -raw k8s_dev_talosconfig / k8s_dev_kubeconfig
output "k8s_dev_talosconfig" {
  description = "talosctl config for k8s-dev"
  value       = data.talos_client_configuration.k8s_dev.talos_config
  sensitive   = true
}

output "k8s_dev_kubeconfig" {
  description = "kubeconfig for k8s-dev (API via the VIP)"
  value       = talos_cluster_kubeconfig.k8s_dev.kubeconfig_raw
  sensitive   = true
}
