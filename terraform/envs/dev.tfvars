# =============================================================================
# Development Environment
# =============================================================================
# Minimal resources, single control-plane, cost-optimized.
# Estimated cost: ~€30/month
#
# Usage:
#   cd terraform
#   terraform plan -var-file=envs/dev.tfvars
#   terraform apply -var-file=envs/dev.tfvars
# =============================================================================

cluster_name = "k8s-dev"
environment  = "dev"

# Single control plane (no HA — acceptable for dev)
control_plane_count       = 1
control_plane_server_type = "cpx21" # 3 vCPU, 4GB RAM
control_plane_image       = "ubuntu-24.04"

# Minimal worker pool
worker_count       = 2
worker_server_type = "cpx21" # 3 vCPU, 4GB RAM
worker_image       = "ubuntu-24.04"

# Location
location     = "nbg1"
network_zone = "eu-central"

# Network
network_cidr = "10.0.0.0/8"
subnet_cidr  = "10.0.0.0/16"

# k3s
k3s_version  = "v1.30.2+k3s1"
pod_cidr     = "10.42.0.0/16"
service_cidr = "10.43.0.0/16"
cluster_dns  = "10.43.0.10"

# Smallest LB
lb_type = "lb11"

labels = {
  environment = "dev"
  managed_by  = "terraform"
}
