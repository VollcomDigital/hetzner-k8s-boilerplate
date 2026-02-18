output "api_server_url" {
  description = "Kubernetes API server URL (via load balancer)"
  value       = "https://${hcloud_load_balancer.api_pre.ipv4}:6443"
}

output "api_lb_ipv4" {
  description = "Public IPv4 of the API load balancer"
  value       = hcloud_load_balancer.api_pre.ipv4
}

output "control_plane_ips" {
  description = "Public IPs of control plane nodes"
  value       = module.servers.control_plane_ips
}

output "worker_ips" {
  description = "Public IPs of worker nodes"
  value       = module.servers.worker_ips
}

output "kubeconfig_path" {
  description = "Path to the generated kubeconfig file"
  value       = abspath("${path.module}/../kubeconfig.yaml")
}

output "ssh_command_cp" {
  description = "SSH command template for control plane nodes"
  value       = "ssh -i ${var.ssh_private_key_path} root@<CONTROL_PLANE_IP>"
}

output "k3s_token" {
  description = "k3s cluster join token"
  value       = module.servers.k3s_token
  sensitive   = true
}
