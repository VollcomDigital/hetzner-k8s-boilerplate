output "lb_id" {
  description = "ID of the API load balancer"
  value       = hcloud_load_balancer.api.id
}

output "lb_ipv4" {
  description = "Public IPv4 of the API load balancer"
  value       = hcloud_load_balancer.api.ipv4
}

output "lb_ipv6" {
  description = "Public IPv6 of the API load balancer"
  value       = hcloud_load_balancer.api.ipv6
}
