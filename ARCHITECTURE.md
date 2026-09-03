# Design notes

This file records why the repository is shaped the way it is. The
[README](README.md) covers how to use it.

## One module, four maps

Every VM on the cluster is the same shape: a full clone of a cloud-init
template, one virtio SCSI disk, one virtio NIC, QEMU guest agent on. The
differences between categories are small and boolean: does it get a GPU, does it
get a raw disk, which bridge is it on, which machine type.

A single module with optional inputs (`gpu_passthrough`, `passthrough_disk`,
`machine_type`) handles all of them through `dynamic` blocks. Four `module`
calls in `main.tf`, each iterating one map from `terraform.tfvars`, set the
category-specific inputs. The earlier layout had four near-identical
`proxmox_vm_qemu` resources of about 85 lines each; a fix in one had to be
copied to the other three.

The maps stay separate rather than being one map with a `type` field because
their object types differ (`storage_vms` needs `drive_id`) and because the
category is what determines the passthrough and bridge inputs. Collapsing them
would move that logic into conditionals inside the module call.

## Configuration in tfvars, not variable defaults

`variables.tf` declares types only. The inventory lives in `terraform.tfvars`,
which is committed. It contains node names, VM IDs, sizes, disk serials, and
the LAN address of the Proxmox API. None of that is secret, and having it in
git means a VM change is a reviewable diff of a few lines.

Anything that is secret comes from Infisical at plan time (see README). The
split into `/HIDDEN` and `/VISIBLE` folders mirrors how the secrets are used:
passwords never leave the provider and cloud-init, while the SSH public key is
also handed out to people.

## Pipeline

```
PR to main ──► Plan job ──► plan posted as PR comment
                  │
   merge          ▼
main push ──► Apply job (serialized) ──► Proxmox
```

There was once a `staging` branch whose only job was to run a plan before a
second PR to `main`. It existed because the GitLab free tier at the time had no
review gates. On GitHub the PR plan comment does that job directly, and one
long-lived branch is one fewer thing to drift.

The apply job re-plans rather than consuming the PR's plan artifact. Handing a
binary plan between two workflow runs is possible but adds artifact plumbing
for a repository where the window between merge and apply is seconds.

## State

State moved from the GitLab-managed backend to S3 with DynamoDB locking when
the repository moved to GitHub. The workflow passes the object key at init
time; the rest of the backend block is static in `versions.tf`. AWS access is
by OIDC role assumption from the runner, so no long-lived keys are stored.

## Migration residue that has been removed

The module refactor used `moved` blocks to relocate the original resources into
module addresses without recreating them. Those blocks were applied long ago
and have been deleted. If you are reading state from before April 2026, the old
addresses were `proxmox_vm_qemu.<category>["<name>"]`.
