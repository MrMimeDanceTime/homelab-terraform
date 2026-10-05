# Infisical Provider - Fetches secrets from Infisical
# Pass credentials via TF_VAR_infisical_client_id and TF_VAR_infisical_client_secret
# environment variables for local use, or GitLab CI variables for pipeline
provider "infisical" {
  host          = "https://app.infisical.com" # Infisical Cloud
  client_id     = var.infisical_client_id
  client_secret = var.infisical_client_secret
}

# Proxmox Provider (bpg)
provider "proxmox" {
  endpoint  = trimsuffix(var.proxmox_api_url, "api2/json")
  api_token = "${var.proxmox_api_token_id}=${data.infisical_secrets.hidden.secrets["pm_api_token_secret"].value}"
  insecure  = var.proxmox_tls_insecure
}

# Fetch secrets from Infisical HIDDEN folder (passwords)
data "infisical_secrets" "hidden" {
  env_slug     = var.infisical_env
  folder_path  = "/HIDDEN"
  workspace_id = var.infisical_workspace_id
}

# Fetch secrets from Infisical VISIBLE folder (SSH keys)
data "infisical_secrets" "visible" {
  env_slug     = var.infisical_env
  folder_path  = "/VISIBLE"
  workspace_id = var.infisical_workspace_id
}
