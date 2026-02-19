# =============================================================================
# Staging Environment
# =============================================================================
# Mirrors production topology at reduced scale for pre-release validation.
# Estimated cost: ~€95/month
#
# Usage:
#   cd terraform
#   terraform plan -var-file=envs/staging.tfvars
#   terraform apply -var-file=envs/staging.tfvars
# =============================================================================

cluster_name = "k8s-staging"
environment  = "staging"

# HA control plane (matches production topology)
control_plane_count       = 3
control_plane_server_type = "cpx21"    # 3 vCPU, 4GB RAM (smaller than prod)
control_plane_image       = "ubuntu-24.04"

# Staging worker pool
worker_count       = 2
worker_server_type = "cpx31"           # 4 vCPU, 8GB RAM
worker_image       = "ubuntu-24.04"

# Location (same as production for realistic testing)
location     = "fsn1"
network_zone = "eu-central"

# Network
network_cidr = "10.0.0.0/8"
subnet_cidr  = "10.0.0.0/16"

# k3s
k3s_version  = "v1.30.2+k3s1"
pod_cidr     = "10.42.0.0/16"
service_cidr = "10.43.0.0/16"
cluster_dns  = "10.43.0.10"

# Load balancer
lb_type = "lb11"

labels = {
  environment = "staging"
  managed_by  = "terraform"
}
