variable "cluster_name" {
  description = "Name prefix for network resources"
  type        = string
}

variable "network_cidr" {
  description = "CIDR block for the private network"
  type        = string
}

variable "subnet_cidr" {
  description = "CIDR block for the cluster subnet"
  type        = string
}

variable "network_zone" {
  description = "Hetzner network zone"
  type        = string
}

variable "labels" {
  description = "Labels to apply to resources"
  type        = map(string)
  default     = {}
}
