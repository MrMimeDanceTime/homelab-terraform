# Architecture Documentation

## Before & After Comparison

### File Structure

#### Before (Monolithic)
```
MaC/
├── main.tf (310 lines)
│   ├── terraform block
│   ├── provider block
│   ├── proxmox_vm_qemu "clone_vms" (85 lines)
│   ├── proxmox_vm_qemu "storage_vms" (85 lines)
│   ├── proxmox_vm_qemu "jellyfin_vms" (85 lines)
│   └── proxmox_vm_qemu "misc_vms" (85 lines)
├── variables.tf (180 lines)
│   ├── vms (with defaults)
│   ├── kube_vms (UNUSED - dead code)
│   ├── jellyfin_vms (with defaults)
│   ├── storage_vms (with defaults)
│   ├── runner_vms (UNUSED - dead code)
│   ├── misc_vms (with defaults)
│   └── secret variables
└── variables.tfvars (26 bytes)
    └── environment = "production"

Total: 3 files, ~520 lines of code
Duplication: ~80% (240+ duplicate lines)
Modules: 0
Secrets: GitLab CI variables
Outputs: None
```

#### After (Modular)
```
MaC/
├── modules/
│   └── proxmox-vm/               # Reusable module
│       ├── main.tf               # 95 lines - VM resource
│       ├── variables.tf          # 107 lines - inputs
│       └── outputs.tf            # 24 lines - outputs
├── main.tf                       # 138 lines - module calls
├── providers.tf                  # 27 lines - provider config
├── versions.tf                   # 12 lines - version constraints
├── variables.tf                  # 110 lines - declarations only
├── locals.tf                     # 27 lines - common values
├── outputs.tf                    # 77 lines - infrastructure outputs
├── terraform.tfvars              # 97 lines - actual config
├── terraform.tfvars.example      # 110 lines - template
├── .gitignore                    # 43 lines
├── README.md                     # 354 lines - documentation
├── MIGRATION.md                  # 234 lines - migration guide
└── ARCHITECTURE.md               # This file

Total: 13 files, ~1,455 lines (but 800 are docs)
Actual Code: ~655 lines
Duplication: ~5% (only common defaults)
Modules: 1 reusable module
Secrets: Infisical integration
Outputs: Full VM information (IPs, IDs, etc.)
```

### Code Reduction

| Metric | Before | After | Improvement |
|--------|--------|-------|-------------|
| main.tf lines | 310 | 138 | ↓ 55% |
| Duplicate code | ~240 lines (80%) | ~30 lines (5%) | ↓ 87.5% |
| VM resource blocks | 4 × 85 lines | 4 × 30 lines | ↓ 65% per VM |
| Files | 3 | 13 | Better organization |
| Documentation | 0 | 588 lines | ∞ improvement |

## Architecture Patterns

### VM Creation Pattern

#### Before (Duplicated Resources)
```hcl
resource "proxmox_vm_qemu" "clone_vms" {
  for_each = var.vms
  name     = each.key
  # ... 85 lines of configuration ...
  cpu { cores = each.value.cpu_cores ... }
  disks { scsi { scsi0 { disk { ... } } } }
  network { bridge = "vmbr0" ... }
  # ... cloud-init config ...
}

resource "proxmox_vm_qemu" "storage_vms" {
  for_each = var.storage_vms
  name     = each.key
  # ... 85 lines of DUPLICATE configuration ...
  cpu { cores = each.value.cpu_cores ... }  # DUPLICATE
  disks { scsi { scsi0 { disk { ... } } } } # DUPLICATE
  disks { scsi { scsi1 { passthrough } } }  # ONLY DIFFERENCE
  network { bridge = "vmbr2" ... }          # ONLY DIFFERENCE
  # ... cloud-init config ...               # DUPLICATE
}

# Same pattern repeated for jellyfin_vms and misc_vms
# Total: 340 lines, 80% duplication
```

#### After (DRY Module)
```hcl
module "vms" {
  source   = "./modules/proxmox-vm"
  for_each = var.vms

  name          = each.key
  cpu_cores     = each.value.cpu_cores
  disk_size     = each.value.disk_size
  # ... only unique values ...
}

module "storage_vms" {
  source   = "./modules/proxmox-vm"
  for_each = var.storage_vms

  # ... same as above ...
  passthrough_disk = each.value.drive_id  # Conditional feature
  network_bridge   = local.storage_bridge # Different network
}

# Total: 138 lines, minimal duplication
```

### Secrets Management

#### Before (GitLab CI Variables)
```yaml
# .gitlab-ci.yml
variables:
  TF_VAR_pm_token_id: $pm_token_id
  TF_VAR_pm_password: $pm_password
  TF_VAR_ssh_key_mrmimedancetime_pub: $ssh_key_mrmimedancetime_pub
  TF_VAR_ci_password: $ci_password
  TF_VAR_root_password: $root_password
```

**Problems**:
- Secrets in CI variables (less secure)
- No rotation mechanism
- Manual management per environment
- No audit trail

#### After (Infisical Integration)
```hcl
# providers.tf
provider "infisical" {
  # Credentials from environment variables
}

data "infisical_secrets" "cloudinit" {
  workspace_id = var.infisical_workspace_id
  env_slug     = var.infisical_env
  folder_path  = var.infisical_folder_path
}

# main.tf
cipassword = data.infisical_secrets.cloudinit.secrets["ci_password"].value
```

**Benefits**:
✅ Centralized secret management
✅ Secret rotation support
✅ Audit trail
✅ Better security
✅ Environment-aware

### Configuration Management

#### Before (Hardcoded Defaults)
```hcl
# variables.tf
variable "vms" {
  type = map(object({ ... }))
  default = {
    "vm1" = {
      home_name = "zeus"
      vm_id     = 200
      # ... hardcoded config in variable default
    }
  }
}
```

**Problems**:
- Configuration mixed with declarations
- Defaults can't be version-controlled separately
- Hard to understand what's required vs optional
- No example template

#### After (Separated Concerns)
```hcl
# variables.tf - declarations only
variable "vms" {
  description = "Map of general-purpose VM configurations"
  type        = map(object({ ... }))
  default     = {}  # Empty default
}

# terraform.tfvars - actual configuration
vms = {
  "vm1" = {
    home_name = "zeus"
    vm_id     = 200
    # ... actual config
  }
}

# terraform.tfvars.example - template
vms = {
  "example-vm" = {
    home_name     = "proxmox-node"
    vm_id         = 100
    # ... example config
  }
}
```

**Benefits**:
✅ Clear separation
✅ Example template for new VMs
✅ Easier to understand
✅ Configuration is version-controlled

## Module Design

### Proxmox VM Module

**Purpose**: Create a single, reusable module that handles all VM variations.

**Features**:
- Standard configuration (CPU, memory, disk, network)
- Conditional GPU passthrough (Jellyfin)
- Conditional disk passthrough (Storage)
- Conditional machine type (Q35 vs default)
- Parameterized storage locations
- Parameterized network bridges

**Interface**:
```hcl
module "example" {
  source = "./modules/proxmox-vm"

  # Required
  name          = string
  target_node   = string
  template_name = string
  cpu_cores     = number
  memory        = number
  disk_size     = number

  # Optional
  vm_id            = number (default: null)
  machine_type     = string (default: null)
  passthrough_disk = string (default: null)
  gpu_passthrough  = object (default: null)

  # Storage
  disk_storage      = string
  cloudinit_storage = string
  network_bridge    = string

  # Cloud-init
  ciuser     = string
  cipassword = string
  sshkeys    = string
}
```

### Locals Pattern

Centralize common values to avoid repetition:

```hcl
# locals.tf
locals {
  default_disk_storage      = "local-lvm"
  default_cloudinit_storage = "local-lvm"
  default_network_bridge    = "vmbr0"
  storage_network_bridge    = "vmbr2"
  default_ciuser            = "mrmimedancetime"

  igpu_passthrough = {
    mapping_id  = "igpu"
    rombar      = true
    pcie        = true
    primary_gpu = false
    vendor_id   = "8086"
  }
}
```

**Usage**:
```hcl
# main.tf
disk_storage   = local.default_disk_storage      # Instead of "local-lvm"
network_bridge = local.default_network_bridge    # Instead of "vmbr0"
gpu_passthrough = local.igpu_passthrough         # Reusable GPU config
```

**Benefits**:
- Single source of truth
- Easy to update globally
- Self-documenting
- No magic strings

## Security Improvements

### Output Protection

All infrastructure outputs marked as sensitive:

```hcl
output "vms" {
  description = "VM information"
  value       = { ... VM IPs, IDs ... }
  sensitive   = true  # Won't show in logs
}
```

**What this means**:
- Outputs won't appear in CLI output
- Outputs won't appear in pipeline logs
- Still accessible via `terraform output` command
- Values stored only in encrypted state file

### State File Security

```yaml
# .gitlab-ci.yml
auto_define_backend: true
auto_encryption: true
auto_encryption_passphrase: $GITLAB_TOFU_AUTO_ENCRYPTION_PASSPHRASE
```

**Protection**:
- State stored in GitLab (encrypted)
- Encryption passphrase in CI variables
- Never committed to git (gitignored)

### Gitignore Protection

```gitignore
# .gitignore
*.tfvars              # Prevent committing secrets
*.tfstate             # Prevent committing state
.terraform/           # Prevent committing plugins
.env*                 # Prevent committing env files
```

## Pipeline Architecture

### Branch-Based Workflow

```
┌─────────────┐
│   Feature   │
│   Branch    │
└──────┬──────┘
       │ (validate only)
       ↓
┌─────────────┐
│   Staging   │ MR → validate
│   Branch    │ Commit → validate + plan
└──────┬──────┘
       │ (review plan)
       ↓
┌─────────────┐
│    Main     │ MR → validate + plan
│   Branch    │ Commit → validate + plan + APPLY
└─────────────┘
```

**Safety Gates**:
1. Feature → Staging MR: Validation only
2. Staging commit: Plan review (no apply)
3. Staging → Main MR: Plan review
4. Main commit: Auto-apply (after reviews)

## Metrics

### Complexity Reduction

**Cyclomatic Complexity**:
- Before: 4 resource blocks × 80 lines = high complexity
- After: 1 module × 95 lines + 4 calls × 30 lines = lower complexity

**Maintainability Index**:
- Before: 310-line file, deep nesting, duplication
- After: Modular structure, separation of concerns, DRY

### Developer Experience

**Adding a VM**:

Before:
1. Find correct resource block (which one?)
2. Copy 85 lines of code
3. Update each field manually
4. Risk copy-paste errors
5. Commit 85 new lines

After:
1. Edit terraform.tfvars
2. Add 8-line config block
3. Commit 8 lines
4. Module handles the rest

**Understanding the code**:

Before:
- Read through 310 lines
- Identify differences between resource blocks
- Understand hardcoded values
- No documentation

After:
- Read README.md for overview
- Check locals.tf for common values
- Module abstracts complexity
- Clear structure and docs

## Future Enhancements

### Potential Improvements

1. **Multiple Proxmox Clusters**:
   ```hcl
   variable "clusters" {
     type = map(object({
       api_url = string
       # ...
     }))
   }
   ```

2. **Environment Workspaces** (if needed):
   ```bash
   terraform workspace new dev
   terraform workspace new staging
   terraform workspace new prod
   ```

3. **Additional Modules**:
   - Proxmox LXC containers
   - Proxmox storage configuration
   - Network configuration

4. **Automated Testing**:
   - `terraform fmt -check` in CI
   - `tflint` for linting
   - `tfsec` for security scanning
   - `checkov` for policy checks

5. **Cost Tracking**:
   - Resource tagging
   - Cost estimation in plan

## Lessons Learned

### What Worked Well

✅ **Module Pattern**: Dramatically reduced duplication
✅ **Infisical Integration**: Better secret management
✅ **Locals**: Centralized common values
✅ **Documentation**: Clear guides and examples
✅ **Outputs**: Visibility into infrastructure

### Design Decisions

**Why single module instead of multiple?**
- VMs are similar enough to share code
- Conditional features handle variations
- Simpler to maintain one module
- Easier for users to understand

**Why not workspaces?**
- User doesn't have true multi-environment setup
- Branch-based workflow works for their use case
- Simpler state management
- Can add later if needed

**Why Infisical over other secret managers?**
- User already mentioned using it
- Good Terraform provider
- Centralized secret management
- Supports rotation and audit

## Conclusion

The refactored architecture achieves:

- **55% reduction** in main.tf size
- **87.5% reduction** in code duplication
- **Better maintainability** through modularity
- **Improved security** via Infisical
- **Better visibility** via outputs
- **Enhanced documentation** for team use

While adding files (3 → 13), the actual code is cleaner, more maintainable, and better organized. The additional files are structure and documentation, not complexity.
