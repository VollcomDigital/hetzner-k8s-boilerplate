output "control_plane_firewall_id" {
  description = "ID of the control plane firewall"
  value       = hcloud_firewall.control_plane.id
}

output "worker_firewall_id" {
  description = "ID of the worker firewall"
  value       = hcloud_firewall.worker.id
}
