locals {
  common_labels = merge(var.labels, {
    environment = var.environment
    managed_by  = "terraform"
  })
}

# ---------------------------------------------------------------------------
# Network — Private VPC for inter-node communication
# ---------------------------------------------------------------------------

module "network" {
  source = "./modules/network"

  cluster_name = var.cluster_name
  network_cidr = var.network_cidr
  subnet_cidr  = var.subnet_cidr
  network_zone = var.network_zone
  labels       = local.common_labels
}

# ---------------------------------------------------------------------------
# Firewalls — Least-privilege ingress/egress rules
# ---------------------------------------------------------------------------

module "firewall" {
  source = "./modules/firewall"

  cluster_name = var.cluster_name
  network_cidr = var.network_cidr
  labels       = local.common_labels
}

# ---------------------------------------------------------------------------
# Load Balancer — HA endpoint for Kubernetes API (port 6443)
# Pre-created so its IP can be injected into cloud-init before servers boot.
# ---------------------------------------------------------------------------

resource "hcloud_load_balancer" "api_pre" {
  name               = "${var.cluster_name}-api-lb"
  load_balancer_type = var.lb_type
  location           = var.location

  labels = merge(local.common_labels, {
    role = "api-server"
  })
}

resource "hcloud_load_balancer_network" "api_pre" {
  load_balancer_id = hcloud_load_balancer.api_pre.id
  network_id       = module.network.network_id

  depends_on = [module.network]
}

resource "hcloud_load_balancer_service" "api" {
  load_balancer_id = hcloud_load_balancer.api_pre.id
  protocol         = "tcp"
  listen_port      = 6443
  destination_port = 6443

  health_check {
    protocol = "tcp"
    port     = 6443
    interval = 10
    timeout  = 5
    retries  = 3
  }
}

resource "hcloud_load_balancer_service" "supervisor" {
  load_balancer_id = hcloud_load_balancer.api_pre.id
  protocol         = "tcp"
  listen_port      = 9345
  destination_port = 9345

  health_check {
    protocol = "tcp"
    port     = 9345
    interval = 10
    timeout  = 5
    retries  = 3
  }
}

# ---------------------------------------------------------------------------
# Servers — Control Plane + Workers with k3s via cloud-init
# ---------------------------------------------------------------------------

module "servers" {
  source = "./modules/server"

  cluster_name = var.cluster_name
  location     = var.location
  hcloud_token = var.hcloud_token

  network_id   = module.network.network_id
  subnet_id    = module.network.subnet_id
  network_cidr = var.network_cidr

  # Control Plane
  control_plane_count            = var.control_plane_count
  control_plane_server_type      = var.control_plane_server_type
  control_plane_image            = var.control_plane_image
  control_plane_firewall_id      = module.firewall.control_plane_firewall_id
  control_plane_locations        = var.control_plane_locations
  cloud_init_control_plane_path  = "${path.module}/cloud-init/control-plane.yaml.tftpl"

  # Workers
  worker_count       = var.worker_count
  worker_server_type = var.worker_server_type
  worker_image       = var.worker_image
  worker_firewall_id = module.firewall.worker_firewall_id
  cloud_init_worker_path = "${path.module}/cloud-init/worker.yaml.tftpl"

  # k3s
  k3s_version     = var.k3s_version
  k3s_token       = var.k3s_token
  api_server_lb_ip = hcloud_load_balancer.api_pre.ipv4
  pod_cidr        = var.pod_cidr
  service_cidr    = var.service_cidr
  cluster_dns     = var.cluster_dns

  # SSH
  ssh_public_key_path = var.ssh_public_key_path

  labels = local.common_labels

  depends_on = [
    module.network,
    module.firewall,
    hcloud_load_balancer.api_pre,
    hcloud_load_balancer_network.api_pre
  ]
}

# ---------------------------------------------------------------------------
# Load Balancer Targets — Attach control plane nodes after creation
# ---------------------------------------------------------------------------

resource "hcloud_load_balancer_target" "control_plane" {
  count            = var.control_plane_count
  load_balancer_id = hcloud_load_balancer.api_pre.id
  type             = "server"
  server_id        = module.servers.control_plane_ids[count.index]
  use_private_ip   = true

  depends_on = [hcloud_load_balancer_network.api_pre]
}

# ---------------------------------------------------------------------------
# Kubeconfig — Fetch from first control-plane node after bootstrap
# ---------------------------------------------------------------------------

resource "null_resource" "kubeconfig" {
  triggers = {
    control_plane_id = module.servers.control_plane_ids[0]
  }

  provisioner "local-exec" {
    command = <<-EOT
      set -euo pipefail
      SSH_OPTS="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=5"
      SSH_KEY="${var.ssh_private_key_path}"
      SSH_HOST="root@${module.servers.control_plane_ips[0]}"
      MAX_RETRIES=60
      RETRY_INTERVAL=10

      echo "Waiting for k3s to initialize on $SSH_HOST..."
      for i in $(seq 1 $MAX_RETRIES); do
        if ssh $SSH_OPTS -i "$SSH_KEY" "$SSH_HOST" \
            'test -f /etc/rancher/k3s/k3s.yaml' 2>/dev/null; then
          echo "k3s config found after $((i * RETRY_INTERVAL))s"
          break
        fi
        if [ "$i" -eq "$MAX_RETRIES" ]; then
          echo "ERROR: k3s did not produce kubeconfig within $((MAX_RETRIES * RETRY_INTERVAL))s"
          exit 1
        fi
        echo "  Attempt $i/$MAX_RETRIES — retrying in ${RETRY_INTERVAL}s..."
        sleep $RETRY_INTERVAL
      done

      ssh $SSH_OPTS -i "$SSH_KEY" "$SSH_HOST" \
        'cat /etc/rancher/k3s/k3s.yaml' \
        | sed 's|https://127.0.0.1:6443|https://${hcloud_load_balancer.api_pre.ipv4}:6443|g' \
        > ${path.module}/../kubeconfig.yaml
      chmod 600 ${path.module}/../kubeconfig.yaml
      echo "Kubeconfig written to kubeconfig.yaml"
    EOT
  }

  depends_on = [
    module.servers,
    hcloud_load_balancer_target.control_plane
  ]
}
