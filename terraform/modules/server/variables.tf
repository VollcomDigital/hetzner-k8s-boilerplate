variable "cluster_name" {
  type = string
}

variable "location" {
  type = string
}

variable "network_id" {
  type = number
}

variable "subnet_id" {
  type = string
}

variable "network_cidr" {
  type = string
}

variable "hcloud_token" {
  type      = string
  sensitive = true
}

# -- Control Plane --

variable "control_plane_count" {
  type = number
}

variable "control_plane_server_type" {
  type = string
}

variable "control_plane_image" {
  type = string
}

variable "control_plane_firewall_id" {
  type = number
}

variable "cloud_init_control_plane_path" {
  type = string
}

# -- Workers --

variable "worker_count" {
  type = number
}

variable "worker_server_type" {
  type = string
}

variable "worker_image" {
  type = string
}

variable "worker_firewall_id" {
  type = number
}

variable "cloud_init_worker_path" {
  type = string
}

# -- k3s --

variable "k3s_version" {
  type = string
}

variable "k3s_token" {
  type      = string
  sensitive = true
  default   = ""
}

variable "api_server_lb_ip" {
  description = "IP of the load balancer fronting the API server"
  type        = string
}

variable "pod_cidr" {
  type = string
}

variable "service_cidr" {
  type = string
}

variable "cluster_dns" {
  type = string
}

# -- SSH --

variable "ssh_public_key_path" {
  type = string
}

# -- Labels --

variable "labels" {
  type    = map(string)
  default = {}
}
