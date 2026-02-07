# Proxmox Infrastructure as Code

This repository manages Proxmox virtual machines using OpenTofu/Terraform with GitLab CI/CD automation.

## Architecture

### Directory Structure

```
MaC/
├── modules/
│   └── proxmox-vm/          # Reusable VM module
│       ├── main.tf          # VM resource definition
│       ├── variables.tf     # Module inputs
│       └── outputs.tf       # Module outputs
├── main.tf                  # Root module - VM definitions
├── variables.tf             # Input variable declarations
├── terraform.tfvars         # Actual configuration (gitignored)
├── terraform.tfvars.example # Configuration template
├── locals.tf                # Common values and constants
├── outputs.tf               # Infrastructure outputs
├── providers.tf             # Provider configurations
├── versions.tf              # Version constraints
└── .gitlab-ci.yml           # CI/CD pipeline
```

### VM Categories

- **General VMs** (`vms`): Standard workload VMs
- **Jellyfin VMs** (`jellyfin_vms`): Media servers with GPU passthrough
- **Storage VMs** (`storage_vms`): GlusterFS nodes with disk passthrough
- **Misc VMs** (`misc_vms`): Miscellaneous Q35 VMs

## Prerequisites

### Required Tools

- [OpenTofu](https://opentofu.org/) >= 1.8.0 (or Terraform >= 1.8.0)
- GitLab account with CI/CD enabled
- Proxmox VE cluster
- Infisical account (for secrets management)

### Required Secrets in Infisical

Store the following secrets in your Infisical workspace:

- `root_password` - Proxmox root password
- `ci_password` - Cloud-init user password
- `ssh_key_pub` - SSH public key for cloud-init user

### GitLab CI/CD Variables

Set these in GitLab CI/CD settings:

- `INFISICAL_CLIENT_ID` - Infisical service token client ID
- `INFISICAL_CLIENT_SECRET` - Infisical service token secret
- `GITLAB_TOFU_AUTO_ENCRYPTION_PASSPHRASE` - State file encryption key

## Setup

### 1. Clone Repository

```bash
git clone <repository-url>
cd MaC
```

### 2. Configure Variables

```bash
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` and set:
- `infisical_workspace_id` - Your Infisical workspace ID
- VM configurations (or use the examples)

### 3. Configure Infisical

Create a service token in Infisical with access to your workspace and add the secrets listed above.

## Usage

### Local Development

**Note**: Local testing requires Infisical credentials to be set:

```bash
export INFISICAL_CLIENT_ID="your-client-id"
export INFISICAL_CLIENT_SECRET="your-client-secret"
```

Initialize Terraform:
```bash
terraform init
```

Validate configuration:
```bash
terraform validate
```

Plan changes:
```bash
terraform plan
```

Apply changes (use with caution):
```bash
terraform apply
```

### GitLab CI/CD Pipeline

The pipeline uses a branch-based workflow:

#### Staging Branch
- **Purpose**: Test and validate changes
- **Triggers**: Commits to `staging` or MRs to `staging`
- **Actions**: `validate` → `plan`
- **Result**: Shows what would change, no apply

#### Main Branch
- **Purpose**: Production deployment
- **Triggers**: Commits to `main` (usually from merging staging)
- **Actions**: `validate` → `plan` → `apply`
- **Result**: Automatically applies changes to infrastructure

#### Workflow

1. Create feature branch from `staging`
2. Make changes and commit
3. Open MR to `staging` - pipeline validates
4. Merge to `staging` - pipeline validates and plans
5. Review plan output
6. Open MR from `staging` to `main` - pipeline validates and plans
7. Merge to `main` - pipeline applies changes

## Module Usage

### Basic VM

```hcl
module "my_vm" {
  source = "./modules/proxmox-vm"

  name          = "my-vm"
  target_node   = "proxmox-node"
  vm_id         = 100
  template_name = "ubuntu-template"

  cpu_cores = 2
  memory    = 4096
  balloon   = 2048
  disk_size = 32

  disk_storage      = "local-lvm"
  cloudinit_storage = "local-lvm"
  network_bridge    = "vmbr0"

  ciuser     = "admin"
  cipassword = var.ci_password
  sshkeys    = var.ssh_key
}
```

### VM with GPU Passthrough

```hcl
module "jellyfin" {
  source = "./modules/proxmox-vm"

  # ... basic config ...

  machine_type = "q35"
  gpu_passthrough = {
    mapping_id  = "igpu"
    rombar      = true
    pcie        = true
    primary_gpu = false
    vendor_id   = "8086"
  }
}
```

### VM with Disk Passthrough

```hcl
module "storage" {
  source = "./modules/proxmox-vm"

  # ... basic config ...

  passthrough_disk = "/dev/disk/by-id/ata-..."
  network_bridge   = "vmbr2"
}
```

## Outputs

All outputs are marked as sensitive and stored only in the encrypted state file.

View outputs:
```bash
terraform output          # List all outputs
terraform output vms      # Specific output
terraform output -json    # JSON format
```

Available outputs:
- `vms` - General VM information
- `storage_vms` - Storage VM information
- `jellyfin_vms` - Jellyfin VM information
- `misc_vms` - Misc VM information
- `vm_summary` - VM counts (non-sensitive)

## Security

### State File
- Stored in GitLab with encryption enabled
- Encrypted with passphrase from CI/CD variable
- Never commit state files to git

### Secrets
- All secrets stored in Infisical
- Never commit `terraform.tfvars` (gitignored)
- Use `terraform.tfvars.example` as template
- Outputs marked sensitive to prevent logging

### TLS Verification
⚠️ **Warning**: TLS verification is disabled by default (`proxmox_tls_insecure = true`)

For production, enable TLS verification:
1. Set up proper SSL certificates on Proxmox
2. Set `proxmox_tls_insecure = false` in `terraform.tfvars`

## Maintenance

### Adding a New VM

1. Edit `terraform.tfvars`
2. Add VM to appropriate map (`vms`, `jellyfin_vms`, etc.)
3. Commit to staging branch
4. Review plan output
5. Merge to main to apply

### Updating a VM

1. Edit VM configuration in `terraform.tfvars`
2. Check `lifecycle.ignore_changes` in module to see what's ignored
3. Commit and review plan
4. Merge to apply

### Removing a VM

1. Remove VM from `terraform.tfvars`
2. Commit to staging and review plan
3. Merge to main - **VM will be destroyed**

### Updating Providers

Renovate bot automatically creates MRs for provider updates.

Manual update:
```bash
terraform init -upgrade
```

## Troubleshooting

### "No Infisical secrets found"
- Verify `infisical_workspace_id` is correct
- Check Infisical service token has correct permissions
- Verify secrets exist in Infisical at specified path

### "State locked"
If pipeline fails mid-run, state may be locked:
```bash
terraform force-unlock <lock-id>
```

### "Resource already exists"
If VM was created outside Terraform:
```bash
terraform import 'module.vms["vm-name"].proxmox_vm_qemu.vm' <proxmox-node>/<vmid>
```

## Migration from Old Structure

This repository was refactored from a monolithic structure to a modular one:

**Changes**:
- 310-line main.tf → 138 lines (55% reduction)
- Removed ~80% code duplication
- Added Infisical integration
- Created reusable module
- Cleaned up dead code (kube_vms, runner_vms)
- Added proper outputs

**State compatibility**: The refactored code produces identical infrastructure. Use `terraform plan` to verify before applying.

## Contributing

1. Create feature branch from `staging`
2. Make changes
3. Open MR to `staging`
4. Review validation results
5. Once merged to staging, review plan output
6. Open MR to `main` for production deployment

## License

[Specify your license here]
