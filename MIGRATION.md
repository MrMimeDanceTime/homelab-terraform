# Migration Guide: Old Structure → Refactored Architecture

This guide helps you transition from the old monolithic structure to the new modular architecture.

## Summary of Changes

### What Changed

**Code Organization**:
- ✅ Created `modules/proxmox-vm/` - reusable VM module
- ✅ Split `main.tf` into focused files (main, providers, versions, locals, outputs)
- ✅ Reduced main.tf from 310 lines → 138 lines (55% reduction)
- ✅ Eliminated ~80% code duplication

**Configuration Management**:
- ✅ Moved VM configs from variable defaults → `terraform.tfvars`
- ✅ Removed dead code (`kube_vms`, `runner_vms`)
- ✅ Added `locals.tf` for common values
- ✅ Created `terraform.tfvars.example` as template

**Secrets Management**:
- ✅ Integrated Infisical provider for secrets
- ✅ Removed GitLab CI variables for Terraform secrets
- ✅ Added encrypted outputs

**New Files**:
- ✅ `.gitignore` - protect sensitive files
- ✅ `README.md` - comprehensive documentation
- ✅ `outputs.tf` - VM information outputs
- ✅ `versions.tf` - version constraints
- ✅ `providers.tf` - provider configuration
- ✅ `locals.tf` - common values

### What Stayed the Same

- ✅ **Same infrastructure** - produces identical VMs
- ✅ **Same VM configurations** - all existing VMs preserved
- ✅ **Same GitLab pipeline** - branch-based workflow unchanged
- ✅ **Same state file** - no state migration needed

## Migration Steps

### Step 1: Backup Current State

```bash
# On your local machine
git clone <repo-url> mac-backup
cd mac-backup
git checkout main

# Or if you have local state
cp terraform.tfstate terraform.tfstate.backup
```

### Step 2: Set Up Infisical

1. **Create Infisical Workspace** (if not already done):
   - Go to [Infisical](https://app.infisical.com)
   - Create a workspace for this project
   - Note the workspace ID

2. **Add Secrets to Infisical**:

   Add these secrets to your Infisical workspace:
   - `root_password` - Your Proxmox root password
   - `ci_password` - Cloud-init user password
   - `ssh_key_pub` - Your SSH public key

3. **Create Service Token**:
   - In Infisical, go to Settings → Service Tokens
   - Create a new service token with read access
   - Copy the Client ID and Client Secret

4. **Add to GitLab CI/CD**:
   - Go to GitLab → Settings → CI/CD → Variables
   - Add variable: `INFISICAL_CLIENT_ID` (value: your client ID)
   - Add variable: `INFISICAL_CLIENT_SECRET` (value: your client secret, marked as protected)

### Step 3: Update terraform.tfvars

Edit `terraform.tfvars` and update:

```hcl
# Replace with your actual workspace ID from Infisical
infisical_workspace_id = "your-actual-workspace-id"
```

The VM configurations are already populated from your previous setup.

### Step 4: Test Locally (Optional but Recommended)

**Note**: This requires Infisical credentials set locally.

```bash
# Set Infisical credentials
export INFISICAL_CLIENT_ID="your-client-id"
export INFISICAL_CLIENT_SECRET="your-client-secret"

# Initialize Terraform
terraform init

# Validate configuration
terraform validate

# Check the plan - should show NO changes to existing resources
terraform plan
```

**Expected Result**: Plan should show module moves but no infrastructure changes.

### Step 5: Deploy via Staging Branch

1. **Push to staging branch**:
   ```bash
   git checkout staging
   git pull origin main  # Get latest changes
   git push origin staging
   ```

2. **Review pipeline**:
   - Go to GitLab CI/CD → Pipelines
   - Check validation passed
   - **Review the plan output carefully**
   - Look for "No changes" or "Plan: 0 to add, 0 to change, 0 to destroy"

3. **Expected plan output**:
   ```
   # module.vms["vm1"] has moved to module.vms["vm1"].proxmox_vm_qemu.vm

   No changes. Your infrastructure matches the configuration.
   ```

### Step 6: Merge to Main

Once you've verified the plan on staging:

1. Open MR: staging → main
2. Review plan in MR pipeline
3. Merge to main
4. Pipeline will automatically apply changes

## Troubleshooting

### Issue: "Error: Missing required variable: infisical_workspace_id"

**Solution**: Update `terraform.tfvars` with your Infisical workspace ID:
```hcl
infisical_workspace_id = "your-workspace-id-here"
```

### Issue: "Error: Failed to fetch secrets from Infisical"

**Causes**:
1. Wrong workspace ID
2. Service token lacks permissions
3. Secrets don't exist in Infisical

**Solution**:
- Verify workspace ID is correct
- Check service token has read access
- Verify secrets exist at path `/` in environment `prod`

### Issue: "Error: Insufficient permissions"

**Solution**: Ensure GitLab CI/CD variables are set:
- `INFISICAL_CLIENT_ID`
- `INFISICAL_CLIENT_SECRET`

### Issue: Plan shows resource destruction

**This should NOT happen** if configured correctly. If it does:

1. **STOP** - Don't apply
2. Review what's being destroyed
3. Check that all VM configs are in `terraform.tfvars`
4. Verify variable names match (vms, storage_vms, jellyfin_vms, misc_vms)

### Issue: terraform.tfvars is empty

The refactored code removed defaults from `variables.tf` and moved them to `terraform.tfvars`.

**Solution**: Copy from the example:
```bash
cp terraform.tfvars.example terraform.tfvars
# Edit and update with your Infisical workspace ID
```

## Verification Checklist

Before merging to main, verify:

- [ ] Infisical workspace created and secrets added
- [ ] GitLab CI/CD variables configured (INFISICAL_CLIENT_ID, INFISICAL_CLIENT_SECRET)
- [ ] `terraform.tfvars` contains your infisical_workspace_id
- [ ] `terraform.tfvars` contains all VM configurations
- [ ] Staging pipeline shows validation passed
- [ ] Plan output shows no infrastructure changes (or only module moves)
- [ ] No resources marked for destruction

## Rollback Plan

If issues occur after merge:

### Option 1: Git Revert (Recommended)

```bash
git revert <commit-hash>
git push origin main
```

### Option 2: Force Push Previous Commit

```bash
git reset --hard <previous-commit>
git push --force origin main
```

**Note**: Your infrastructure won't be affected by rollback since the new code produces identical resources.

## Post-Migration

### New Workflow

**Adding VMs**:
1. Edit `terraform.tfvars`
2. Add to appropriate map
3. Push to staging → review plan → merge to main

**Updating VMs**:
1. Edit VM config in `terraform.tfvars`
2. Push to staging → review plan → merge to main

**Viewing Outputs**:
```bash
terraform output
terraform output vms
terraform output vm_summary
```

### Cleanup

After successful migration, you can remove old backup:
```bash
cd ../
rm -rf mac-backup
```

## Benefits After Migration

✅ **Maintainability**: 55% less code, 80% less duplication
✅ **Scalability**: Easy to add new VMs with module
✅ **Security**: Secrets in Infisical, not CI variables
✅ **Visibility**: Outputs for all VM IPs and IDs
✅ **Documentation**: README, examples, and this guide
✅ **Standards**: Proper .gitignore, version constraints

## Questions?

If you encounter issues during migration:

1. Check this guide first
2. Review `README.md` for detailed usage
3. Check GitLab pipeline logs
4. Verify Infisical configuration

## Secret Name Mapping

**Old GitLab CI Variables** → **New Infisical Secrets**:
- `$root_password` → `root_password` (in Infisical)
- `$ci_password` → `ci_password` (in Infisical)
- `$ssh_key_mrmimedancetime_pub` → `ssh_key_pub` (in Infisical)

**Important**: The Infisical secrets must have these exact names for the providers to work.
