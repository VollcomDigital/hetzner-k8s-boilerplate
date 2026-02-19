resource "hcloud_firewall" "control_plane" {
  name = "${var.cluster_name}-control-plane"

  labels = merge(var.labels, {
    cluster = var.cluster_name
    role    = "control-plane"
  })

  # SSH access
  rule {
    direction  = "in"
    protocol   = "tcp"
    port       = "22"
    source_ips = var.ssh_allowed_cidrs
  }

  # Kubernetes API server
  rule {
    direction  = "in"
    protocol   = "tcp"
    port       = "6443"
    source_ips = var.api_allowed_cidrs
  }

  # etcd peer communication (control plane only)
  rule {
    direction  = "in"
    protocol   = "tcp"
    port       = "2379-2380"
    source_ips = [var.network_cidr]
  }

  # Kubelet API
  rule {
    direction  = "in"
    protocol   = "tcp"
    port       = "10250"
    source_ips = [var.network_cidr]
  }

  # k3s supervisor / embedded registry
  rule {
    direction  = "in"
    protocol   = "tcp"
    port       = "9345"
    source_ips = [var.network_cidr]
  }

  # Flannel VXLAN (k3s default, kept for compatibility)
  rule {
    direction  = "in"
    protocol   = "udp"
    port       = "8472"
    source_ips = [var.network_cidr]
  }

  # Cilium health checks
  rule {
    direction  = "in"
    protocol   = "tcp"
    port       = "4240"
    source_ips = [var.network_cidr]
  }

  # Cilium VXLAN
  rule {
    direction  = "in"
    protocol   = "udp"
    port       = "8473"
    source_ips = [var.network_cidr]
  }

  # WireGuard (Cilium encryption)
  rule {
    direction  = "in"
    protocol   = "udp"
    port       = "51871"
    source_ips = [var.network_cidr]
  }

  # NodePort range
  rule {
    direction  = "in"
    protocol   = "tcp"
    port       = "30000-32767"
    source_ips = ["0.0.0.0/0", "::/0"]
  }

  # ICMP (ping)
  rule {
    direction  = "in"
    protocol   = "icmp"
    source_ips = ["0.0.0.0/0", "::/0"]
  }

  # Allow all outbound
  rule {
    direction       = "out"
    protocol        = "tcp"
    port            = "1-65535"
    destination_ips = ["0.0.0.0/0", "::/0"]
  }

  rule {
    direction       = "out"
    protocol        = "udp"
    port            = "1-65535"
    destination_ips = ["0.0.0.0/0", "::/0"]
  }

  rule {
    direction       = "out"
    protocol        = "icmp"
    destination_ips = ["0.0.0.0/0", "::/0"]
  }
}

resource "hcloud_firewall" "worker" {
  name = "${var.cluster_name}-worker"

  labels = merge(var.labels, {
    cluster = var.cluster_name
    role    = "worker"
  })

  # SSH access
  rule {
    direction  = "in"
    protocol   = "tcp"
    port       = "22"
    source_ips = var.ssh_allowed_cidrs
  }

  # Kubelet API
  rule {
    direction  = "in"
    protocol   = "tcp"
    port       = "10250"
    source_ips = [var.network_cidr]
  }

  # Flannel VXLAN
  rule {
    direction  = "in"
    protocol   = "udp"
    port       = "8472"
    source_ips = [var.network_cidr]
  }

  # Cilium health checks
  rule {
    direction  = "in"
    protocol   = "tcp"
    port       = "4240"
    source_ips = [var.network_cidr]
  }

  # Cilium VXLAN
  rule {
    direction  = "in"
    protocol   = "udp"
    port       = "8473"
    source_ips = [var.network_cidr]
  }

  # WireGuard (Cilium encryption)
  rule {
    direction  = "in"
    protocol   = "udp"
    port       = "51871"
    source_ips = [var.network_cidr]
  }

  # HTTP/HTTPS (Ingress)
  rule {
    direction  = "in"
    protocol   = "tcp"
    port       = "80"
    source_ips = ["0.0.0.0/0", "::/0"]
  }

  rule {
    direction  = "in"
    protocol   = "tcp"
    port       = "443"
    source_ips = ["0.0.0.0/0", "::/0"]
  }

  # NodePort range
  rule {
    direction  = "in"
    protocol   = "tcp"
    port       = "30000-32767"
    source_ips = ["0.0.0.0/0", "::/0"]
  }

  # ICMP
  rule {
    direction  = "in"
    protocol   = "icmp"
    source_ips = ["0.0.0.0/0", "::/0"]
  }

  # Allow all outbound
  rule {
    direction       = "out"
    protocol        = "tcp"
    port            = "1-65535"
    destination_ips = ["0.0.0.0/0", "::/0"]
  }

  rule {
    direction       = "out"
    protocol        = "udp"
    port            = "1-65535"
    destination_ips = ["0.0.0.0/0", "::/0"]
  }

  rule {
    direction       = "out"
    protocol        = "icmp"
    destination_ips = ["0.0.0.0/0", "::/0"]
  }
}
