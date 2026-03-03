output "control_plane_ips" {
  description = "Public IPv4 addresses of control plane nodes"
  value       = hcloud_server.control_plane[*].ipv4_address
}

output "control_plane_private_ips" {
  description = "Private IPs of control plane nodes"
  value       = [for s in hcloud_server.control_plane : s.network[*].ip]
}

output "worker_ips" {
  description = "Public IPv4 addresses of worker nodes"
  value       = hcloud_server.worker[*].ipv4_address
}

output "worker_private_ips" {
  description = "Private IPs of worker nodes"
  value       = [for s in hcloud_server.worker : s.network[*].ip]
}

output "control_plane_ids" {
  description = "Server IDs of control plane nodes"
  value       = hcloud_server.control_plane[*].id
}

output "worker_ids" {
  description = "Server IDs of worker nodes"
  value       = hcloud_server.worker[*].id
}

output "ssh_key_id" {
  description = "ID of the SSH key"
  value       = hcloud_ssh_key.cluster.id
}

output "observability_ips" {
  description = "Public IPv4 addresses of observability nodes"
  value       = hcloud_server.observability[*].ipv4_address
}

output "observability_ids" {
  description = "Server IDs of observability nodes"
  value       = hcloud_server.observability[*].id
}

output "k3s_token" {
  description = "k3s cluster join token"
  value       = local.k3s_token
  sensitive   = true
}
