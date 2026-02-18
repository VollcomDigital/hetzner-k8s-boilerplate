resource "hcloud_ssh_key" "cluster" {
  name       = "${var.cluster_name}-key"
  public_key = file(pathexpand(var.ssh_public_key_path))

  labels = merge(var.labels, {
    cluster = var.cluster_name
  })
}

# Generate k3s token if not provided
resource "random_password" "k3s_token" {
  count   = var.k3s_token == "" ? 1 : 0
  length  = 48
  special = false
}

locals {
  k3s_token = var.k3s_token != "" ? var.k3s_token : random_password.k3s_token[0].result

  common_labels = merge(var.labels, {
    cluster = var.cluster_name
  })
}

# ---------------------------------------------------------------------------
# Control Plane Nodes
# ---------------------------------------------------------------------------

resource "hcloud_placement_group" "control_plane" {
  name = "${var.cluster_name}-control-plane"
  type = "spread"

  labels = merge(local.common_labels, {
    role = "control-plane"
  })
}

resource "hcloud_server" "control_plane" {
  count = var.control_plane_count

  name        = "${var.cluster_name}-cp-${count.index}"
  server_type = var.control_plane_server_type
  image       = var.control_plane_image
  location    = var.location

  ssh_keys           = [hcloud_ssh_key.cluster.id]
  placement_group_id = hcloud_placement_group.control_plane.id
  firewall_ids       = [var.control_plane_firewall_id]

  labels = merge(local.common_labels, {
    role  = "control-plane"
    index = tostring(count.index)
  })

  user_data = templatefile(var.cloud_init_control_plane_path, {
    k3s_version     = var.k3s_version
    k3s_token       = local.k3s_token
    is_first_server = count.index == 0
    api_server_lb   = var.api_server_lb_ip
    node_name       = "${var.cluster_name}-cp-${count.index}"
    cluster_name    = var.cluster_name
    network_cidr    = var.network_cidr
    pod_cidr        = var.pod_cidr
    service_cidr    = var.service_cidr
    cluster_dns     = var.cluster_dns
    hcloud_token    = var.hcloud_token
  })

  network {
    network_id = var.network_id
  }

  public_net {
    ipv4_enabled = true
    ipv6_enabled = true
  }

  lifecycle {
    ignore_changes = [user_data, ssh_keys]
  }

  depends_on = [var.subnet_id]
}

# ---------------------------------------------------------------------------
# Worker Nodes
# ---------------------------------------------------------------------------

resource "hcloud_placement_group" "worker" {
  name = "${var.cluster_name}-worker"
  type = "spread"

  labels = merge(local.common_labels, {
    role = "worker"
  })
}

resource "hcloud_server" "worker" {
  count = var.worker_count

  name        = "${var.cluster_name}-worker-${count.index}"
  server_type = var.worker_server_type
  image       = var.worker_image
  location    = var.location

  ssh_keys           = [hcloud_ssh_key.cluster.id]
  placement_group_id = hcloud_placement_group.worker.id
  firewall_ids       = [var.worker_firewall_id]

  labels = merge(local.common_labels, {
    role  = "worker"
    index = tostring(count.index)
  })

  user_data = templatefile(var.cloud_init_worker_path, {
    k3s_version   = var.k3s_version
    k3s_token     = local.k3s_token
    api_server_lb = var.api_server_lb_ip
    node_name     = "${var.cluster_name}-worker-${count.index}"
    cluster_name  = var.cluster_name
    network_cidr  = var.network_cidr
  })

  network {
    network_id = var.network_id
  }

  public_net {
    ipv4_enabled = true
    ipv6_enabled = true
  }

  lifecycle {
    ignore_changes = [user_data, ssh_keys]
  }

  depends_on = [
    var.subnet_id,
    hcloud_server.control_plane
  ]
}
