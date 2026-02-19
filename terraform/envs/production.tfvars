# =============================================================================
# Production Environment
# =============================================================================
# HA control plane, larger workers, full redundancy.
# Estimated cost: ~€175/month (servers + LB + volumes)
#
# Usage:
#   cd terraform
#   terraform plan -var-file=envs/production.tfvars
#   terraform apply -var-file=envs/production.tfvars
# =============================================================================

cluster_name = "k8s-prod"
environment  = "production"

# HA control plane (3 nodes, spread placement group)
control_plane_count       = 3
control_plane_server_type = "cpx31"    # 4 vCPU, 8GB RAM
control_plane_image       = "ubuntu-24.04"

# Production worker pool
worker_count       = 3
worker_server_type = "cpx41"           # 8 vCPU, 16GB RAM
worker_image       = "ubuntu-24.04"

# Location
location     = "fsn1"                  # Falkenstein (good connectivity)
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
  environment = "production"
  managed_by  = "terraform"
  team        = "platform"
}
