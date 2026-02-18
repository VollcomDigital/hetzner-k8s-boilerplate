resource "hcloud_load_balancer" "api" {
  name               = "${var.cluster_name}-api-lb"
  load_balancer_type = var.lb_type
  location           = var.location

  labels = merge(var.labels, {
    cluster = var.cluster_name
    role    = "api-server"
  })
}

resource "hcloud_load_balancer_network" "api" {
  load_balancer_id = hcloud_load_balancer.api.id
  network_id       = var.network_id
}

resource "hcloud_load_balancer_service" "api" {
  load_balancer_id = hcloud_load_balancer.api.id
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

# k3s supervisor port for node join
resource "hcloud_load_balancer_service" "supervisor" {
  load_balancer_id = hcloud_load_balancer.api.id
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

resource "hcloud_load_balancer_target" "control_plane" {
  count            = length(var.control_plane_server_ids)
  load_balancer_id = hcloud_load_balancer.api.id
  type             = "server"
  server_id        = var.control_plane_server_ids[count.index]
  use_private_ip   = true

  depends_on = [hcloud_load_balancer_network.api]
}
