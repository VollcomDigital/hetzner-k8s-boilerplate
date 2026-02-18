output "network_id" {
  description = "ID of the private network"
  value       = hcloud_network.cluster.id
}

output "subnet_id" {
  description = "ID of the cluster subnet"
  value       = hcloud_network_subnet.cluster.id
}

output "network_cidr" {
  description = "CIDR of the private network"
  value       = hcloud_network.cluster.ip_range
}
