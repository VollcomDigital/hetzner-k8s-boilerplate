variable "cluster_name" {
  description = "Name prefix for firewall resources"
  type        = string
}

variable "network_cidr" {
  description = "CIDR of the private network for internal rules"
  type        = string
}

variable "ssh_allowed_cidrs" {
  description = "CIDRs allowed SSH access (restrict in production)"
  type        = list(string)
  default     = ["0.0.0.0/0", "::/0"]
}

variable "api_allowed_cidrs" {
  description = "CIDRs allowed access to the Kubernetes API"
  type        = list(string)
  default     = ["0.0.0.0/0", "::/0"]
}

variable "labels" {
  description = "Labels to apply to resources"
  type        = map(string)
  default     = {}
}
