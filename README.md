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
2. The `Plan` job runs `fmt`, `validate`, a gating Checkov scan, and
   `tofu plan`, then posts the plan as a comment on the PR. Pushing again
   updates the same comment. The plan file is encrypted and uploaded as an
   artifact together with the hash of the tree it was planned against.
3. Squash-merge. The `Apply reviewed plan` job applies that exact plan file
   without re-planning. It refuses to run when:
   - the push to `main` did not come from a merged PR
   - the PR's newest plan was made on an older head than the one merged
   - `main`'s tree differs from the planned tree (something else merged)

   OpenTofu also refuses a saved plan if state changed after it was made.

A nightly `Drift check` plans `main` with `-detailed-exitcode` and posts to
Discord if Proxmox no longer matches. Running the workflow by hand with
`apply=true` re-plans `main` and applies it: the escape hatch for when no
reviewed plan exists. Apply and drift runs share a concurrency group.

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
| `PLAN_ENCRYPTION_KEY`     | Encrypts the plan artifact, which holds Infisical values |
| `MIRROR_DEPLOY_KEY`       | Pushes the scrubbed public mirror                 |

No AWS keys and no Proxmox credentials are stored in GitHub.

### Public mirror

This repo is private so the self-hosted runner accepts its jobs. The
`Public mirror` workflow publishes a scrubbed copy of `main` to
[MrMimeDanceTime/homelab-terraform](https://github.com/MrMimeDanceTime/homelab-terraform)
on every push: `git filter-repo` strips `terraform.tfvars`, `.claude/`, and
`.github/mirror/` from all history and rewrites the strings in
`.github/mirror/replacements.txt`. A verify step fails the job before pushing if
any of them survive. Never commit to the mirror directly.

## Secrets

Everything sensitive lives in Infisical and is read at plan time:

| Infisical path          | Key             | Used as                       |
|-------------------------|-----------------|-------------------------------|
| `/HIDDEN`               | `pm_api_token_secret` | Proxmox API token secret (`terraform@pve!tofu`) |
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
tofu import 'module.vms["name"].proxmox_virtual_environment_vm.vm' <node>/<vmid>
```

Or, better, an `import` block in a PR so the import goes through review.

## Module interface

`modules/proxmox-vm` creates one `proxmox_virtual_environment_vm` resource
([bpg/proxmox](https://registry.terraform.io/providers/bpg/proxmox/latest)).
The root module resolves `template_name` from `terraform.tfvars` to a template
VM ID and node through the `proxmox_virtual_environment_vms` data source.

| Input               | Required | Notes                                           |
|---------------------|----------|-------------------------------------------------|
| `name`, `target_node` | yes | |
| `template_vm_id`, `template_node` | yes | Clone source |
| `cpu_cores`, `memory`, `balloon`, `disk_size` | yes | Sizing |
| `disk_storage`, `cloudinit_storage`, `network_bridge` | yes | Usually from `locals.tf` |
| `ciuser`, `cipassword`, `sshkeys` | yes | Cloud-init identity |
| `vm_id`             | no       | Proxmox picks one if null                       |
| `machine_type`      | no       | `q35` is required for PCIe passthrough          |
| `passthrough_disk`, `passthrough_disk_size` | no | Adds `scsi1` as a raw passthrough of this device. Size must match what PVE reports |
| `gpu_passthrough`   | no       | Object with `mapping_id`, `rombar`, `pcie`, `primary_gpu` |

Outputs: `id`, `vmid`, `name`, `default_ipv4_address`, `ssh_host`.

`clone` and `initialization` are in `ignore_changes`. Every clone attribute
forces replacement and imported VMs have none recorded; cloud-init is read on
first boot only. Rotating the key in Infisical does not touch existing VMs.

`reboot_after_update` is `false`: a change that needs a reboot fails the apply
instead of power-cycling the VM.

## Templates

`templates.tf` downloads a pinned release from
[homelab-images](https://github.com/MrMimeDanceTime/homelab-images) into
`zeus:local` (content type `import`), checks its SHA-512, and imports it as a
template on the shared `ssd` Ceph pool, so one template serves every node.
To move to a newer image, change the tag and digest in a PR.

Build template disks with `import_from`, never `file_id`. bpg imports a
`file_id` disk over SSH to the node, and CI has no SSH key; `import_from` goes
through the PVE API. It needs the source on storage with `import` content,
which `local` has.

## Proxmox permissions

The token is `terraform@pve!tofu` with privilege separation off, so it has
exactly the user's permissions:

| Path | Role | Privileges |
|---|---|---|
| `/` | `TerraformProv` | The provider's PVE 9 list, plus `VM.GuestAgent.Audit` (agent IP reads) and `Mapping.Use` (the `igpu` PCI mapping) |
| `/storage/local` | `TerraformStorage` | `Datastore.Allocate`, `Datastore.AllocateSpace`, `Datastore.AllocateTemplate`, `Datastore.Audit` |

`TerraformStorage` exists because replacing a downloaded image deletes a file,
which needs `Datastore.Allocate`. That privilege also allows editing the
storage definition, so it is granted on `local` only.

**An ACL on a deeper path replaces what the user inherits from above; it does
not add to it.** That is why `TerraformStorage` repeats the datastore
privileges `TerraformProv` already grants on `/`: with only
`Datastore.Allocate` there, downloads to `local` lost
`Datastore.AllocateTemplate`. Any future per-path role must carry everything
Terraform does at that path.

## Known compromises

- PVE only lets `root@pam` attach or change a raw `/dev/disk/by-id` device,
  so creating a storage VM or changing its passthrough disk is a manual root
  operation (`qm set`), followed by a PR that makes the config match.
- TLS verification is disabled because the cluster uses the self-signed
  Proxmox certificate. It is set explicitly in `terraform.tfvars`.
- Without branch protection (a private repo on GitHub Free), the guarantee
  that only reviewed plans apply lives in the workflow, not in GitHub settings.

See [ARCHITECTURE.md](ARCHITECTURE.md) for the reasoning behind the structure.
