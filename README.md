# Proxmox Infrastructure as Code

OpenTofu configuration for the VMs running on a small Proxmox VE cluster (nodes
`zeus`, `apollo`, `hades`, `poseidon`). Every VM is a cloud-init clone of a
per-node AlmaLinux template, described by a few lines in `terraform.tfvars` and
built by one reusable module.

Changes are deployed by GitHub Actions on a self-hosted runner inside the
network: a pull request produces a plan as a PR comment, and merging to `main`
applies it.

## Layout

```
.
├── main.tf                     # Four module calls, one per VM category
├── variables.tf                # Input declarations (no environment-specific defaults)
├── terraform.tfvars            # The actual VM inventory (committed; contains no secrets)
├── terraform.tfvars.example    # Template for a fresh environment
├── locals.tf                   # Shared values: storage pools, bridges, GPU mapping
├── providers.tf                # Proxmox + Infisical providers, secret lookups
├── versions.tf                 # OpenTofu + provider pins, S3 backend
├── outputs.tf                  # VM IDs and addresses (sensitive) plus counts
├── modules/proxmox-vm/         # The VM module
└── .github/workflows/terraform.yml
```

### VM categories

| Map            | Traits                                              |
|----------------|-----------------------------------------------------|
| `vms`          | General purpose                                     |
| `jellyfin_vms` | q35 machine type, Intel iGPU passthrough            |
| `storage_vms`  | GlusterFS nodes, whole-disk passthrough, storage bridge |
| `misc_vms`     | q35 machine type, no passthrough                    |

All four use the same module. The differences are a handful of inputs set in
`main.tf`, so adding a category is a new map plus a module call.

## How a change ships

1. Branch from `main`, edit `terraform.tfvars` (or the module), open a PR.
2. The `Plan` job runs `fmt`, `validate`, a Checkov scan, and `tofu plan`, then
   posts the plan as a comment on the PR. Pushing again updates the same comment.
3. Merge. The `Apply` job re-plans against `main` and applies with
   `-auto-approve`. Apply runs are serialized through a concurrency group so two
   merges cannot apply at once.

Renovate opens PRs against `main` weekly for provider and action updates. They
go through the same plan step.

There is no separate staging environment. The PR plan is the review gate.

### Runner and credentials

The workflow runs on a self-hosted runner because the Proxmox API is only
reachable from inside the network. It needs these repository secrets:

| Secret                    | Used for                                         |
|---------------------------|--------------------------------------------------|
| `AWS_ROLE_ARN`            | OIDC role assumed for S3 state and DynamoDB locks |
| `INFISICAL_CLIENT_ID`     | Infisical machine identity                        |
| `INFISICAL_CLIENT_SECRET` | Infisical machine identity                        |
| `DISCORD_WEBHOOK`         | Job status notifications                          |

No AWS keys and no Proxmox credentials are stored in GitHub.

## Secrets

Everything sensitive lives in Infisical and is read at plan time:

| Infisical path          | Key             | Used as                       |
|-------------------------|-----------------|-------------------------------|
| `/HIDDEN`               | `root_password` | Proxmox API password          |
| `/HIDDEN`               | `ci_password`   | Cloud-init user password      |
| `/VISIBLE`              | `ssh_key_pub`   | Cloud-init authorized key     |

The provider authenticates with a machine identity passed through
`TF_VAR_infisical_client_id` and `TF_VAR_infisical_client_secret`. Locally,
export those two variables before running OpenTofu.

## State

State is in S3 (`mac-iac-tfstate`, `us-west-2`) with server-side encryption and
a DynamoDB lock table. The object key is passed at init time by the workflow
(`env:/production/terraform.tfstate`). The lockfile `.terraform.lock.hcl` is
committed so CI and local runs resolve identical provider builds.

## Local use

```bash
export TF_VAR_infisical_client_id=...
export TF_VAR_infisical_client_secret=...
# AWS credentials for the state bucket via your usual mechanism (profile, SSO, env)

tofu init -backend-config="key=env:/production/terraform.tfstate"
tofu fmt -check -recursive
tofu validate
tofu plan -var-file=terraform.tfvars
```

Prefer opening a PR over applying locally, so the change is recorded and the
plan is reviewed.

## Common tasks

**Add a VM.** Add an entry to the right map in `terraform.tfvars`. Every VM
needs `home_name` (Proxmox node), `vm_id`, `cpu_cores`, `memory`, `balloon`
(`0` disables ballooning), `disk_size` in GB, and `template_name`. Storage VMs
also need `drive_id`, the `/dev/disk/by-id/...` path of the disk to pass
through.

**Resize a VM.** Change the numbers. CPU, memory, and disk growth apply in
place; disk shrink is not supported by Proxmox.

**Remove a VM.** Delete its entry. The plan will show a destroy. Merge only if
that is what you want.

**Import a VM built by hand.**

```bash
tofu import 'module.vms["name"].proxmox_vm_qemu.vm' <node>/<vmid>
```

## Module interface

`modules/proxmox-vm` creates one `proxmox_vm_qemu` resource.

| Input               | Required | Notes                                           |
|---------------------|----------|-------------------------------------------------|
| `name`, `target_node`, `template_name` | yes | Clone source is looked up by name on the node |
| `cpu_cores`, `memory`, `balloon`, `disk_size` | yes | Sizing |
| `disk_storage`, `cloudinit_storage`, `network_bridge` | yes | Usually from `locals.tf` |
| `ciuser`, `cipassword`, `sshkeys` | yes | Cloud-init identity |
| `vm_id`             | no       | Proxmox picks one if null                       |
| `machine_type`      | no       | `q35` is required for PCIe passthrough          |
| `passthrough_disk`  | no       | Adds `scsi1` as a raw passthrough of this device |
| `gpu_passthrough`   | no       | Object with `mapping_id`, `rombar`, `pcie`, `primary_gpu`, `vendor_id` |

Outputs: `id`, `vmid`, `name`, `default_ipv4_address`, `ssh_host`.

`sshkeys` and `ipconfig0` are in `ignore_changes` because cloud-init only reads
them on first boot. Rotating the key in Infisical does not touch existing VMs.

## Known compromises

- The Proxmox provider is `Telmate/proxmox` pinned to `3.0.1-rc9`. The 3.x line
  has only shipped release candidates, so there is no stable target yet.
- Authentication is `root@pam` with a password rather than an API token, and
  TLS verification is disabled because the cluster uses the self-signed
  Proxmox certificate. Both are set explicitly in `terraform.tfvars`.
- The plan shown on the PR and the plan applied after merge are separate runs.
  Applying the exact reviewed plan would need the artifact handed between
  workflow runs, which is more machinery than this repo warrants.

See [ARCHITECTURE.md](ARCHITECTURE.md) for the reasoning behind the structure.
