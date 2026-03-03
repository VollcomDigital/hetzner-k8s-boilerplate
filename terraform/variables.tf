# -----------------------------------------------------------------------------
# Authentication
# -----------------------------------------------------------------------------

variable "hcloud_token" {
  description = "Hetzner Cloud API token (read/write)"
  type        = string
  sensitive   = true
}

# -----------------------------------------------------------------------------
# Cluster Metadata
# -----------------------------------------------------------------------------

variable "cluster_name" {
  description = "Name prefix for all resources"
  type        = string
  default     = "k8s"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,20}$", var.cluster_name))
    error_message = "Cluster name must be lowercase alphanumeric with hyphens, 2-21 chars."
  }
}

variable "environment" {
  description = "Deployment environment (dev, staging, production)"
  type        = string
  default     = "production"

  validation {
    condition     = contains(["dev", "staging", "production"], var.environment)
    error_message = "Environment must be one of: dev, staging, production."
  }
}

# -----------------------------------------------------------------------------
# Location
# -----------------------------------------------------------------------------

variable "location" {
  description = "Primary Hetzner datacenter location (nbg1, fsn1, hel1, ash, hil)"
  type        = string
  default     = "nbg1"

  validation {
    condition     = contains(["nbg1", "fsn1", "hel1", "ash", "hil"], var.location)
    error_message = "Location must be a valid Hetzner datacenter."
  }
}

variable "control_plane_locations" {
  description = "Locations for control-plane nodes for multi-zone HA. If empty, all CP nodes use var.location. Must be within the same network_zone."
  type        = list(string)
  default     = []

  validation {
    condition     = alltrue([for l in var.control_plane_locations : contains(["nbg1", "fsn1", "hel1", "ash", "hil"], l)])
    error_message = "All locations must be valid Hetzner datacenters."
  }
}

variable "network_zone" {
  description = "Hetzner network zone (eu-central, us-east, us-west)"
  type        = string
  default     = "eu-central"
}

# -----------------------------------------------------------------------------
# Network
# -----------------------------------------------------------------------------

variable "network_cidr" {
  description = "CIDR block for the private network"
  type        = string
  default     = "10.0.0.0/8"
}

variable "subnet_cidr" {
  description = "CIDR block for the cluster subnet"
  type        = string
  default     = "10.0.0.0/16"
}

# -----------------------------------------------------------------------------
# Control Plane Nodes
# -----------------------------------------------------------------------------

variable "control_plane_count" {
  description = "Number of control plane nodes (use 1 for dev, 3 for HA production)"
  type        = number
  default     = 3

  validation {
    condition     = contains([1, 3], var.control_plane_count)
    error_message = "Control plane count must be 1 (single) or 3 (HA)."
  }
}

variable "control_plane_server_type" {
  description = "Hetzner server type for control plane nodes"
  type        = string
  default     = "cpx31"
}

variable "control_plane_image" {
  description = "OS image for control plane nodes"
  type        = string
  default     = "ubuntu-24.04"
}

# -----------------------------------------------------------------------------
# Worker Nodes
# -----------------------------------------------------------------------------

variable "worker_count" {
  description = "Number of worker nodes"
  type        = number
  default     = 3

  validation {
    condition     = var.worker_count >= 1 && var.worker_count <= 50
    error_message = "Worker count must be between 1 and 50."
  }
}

variable "worker_server_type" {
  description = "Hetzner server type for worker nodes"
  type        = string
  default     = "cpx31"
}

variable "worker_image" {
  description = "OS image for worker nodes"
  type        = string
  default     = "ubuntu-24.04"
}

# -----------------------------------------------------------------------------
# k3s Configuration
# -----------------------------------------------------------------------------

variable "k3s_version" {
  description = "k3s version to install (e.g., v1.30.2+k3s1)"
  type        = string
  default     = "v1.30.2+k3s1"
}

variable "k3s_token" {
  description = "Shared secret for k3s node registration (auto-generated if empty)"
  type        = string
  sensitive   = true
  default     = ""
}

variable "pod_cidr" {
  description = "CIDR for pod network"
  type        = string
  default     = "10.42.0.0/16"
}

variable "service_cidr" {
  description = "CIDR for service network"
  type        = string
  default     = "10.43.0.0/16"
}

variable "cluster_dns" {
  description = "Cluster DNS service IP"
  type        = string
  default     = "10.43.0.10"
}

# -----------------------------------------------------------------------------
# SSH
# -----------------------------------------------------------------------------

variable "ssh_public_key_path" {
  description = "Path to SSH public key for server access"
  type        = string
  default     = "~/.ssh/id_ed25519.pub"
}

variable "ssh_private_key_path" {
  description = "Path to SSH private key for provisioning"
  type        = string
  default     = "~/.ssh/id_ed25519"
}

# -----------------------------------------------------------------------------
# Load Balancer
# -----------------------------------------------------------------------------

variable "lb_type" {
  description = "Hetzner Load Balancer type for API server"
  type        = string
  default     = "lb11"
}

# -----------------------------------------------------------------------------
# Observability Nodes
# -----------------------------------------------------------------------------

variable "observability_node_count" {
  description = "Number of dedicated observability nodes (0 = disabled, co-locate with workers)"
  type        = number
  default     = 2

  validation {
    condition     = var.observability_node_count >= 0 && var.observability_node_count <= 10
    error_message = "Observability node count must be between 0 and 10."
  }
}

variable "observability_server_type" {
  description = "Hetzner server type for observability nodes (recommend high-RAM: cx52, cpx51)"
  type        = string
  default     = "cx52"
}

variable "observability_image" {
  description = "OS image for observability nodes"
  type        = string
  default     = "ubuntu-24.04"
}

# -----------------------------------------------------------------------------
# Labels
# -----------------------------------------------------------------------------

variable "labels" {
  description = "Labels to apply to all resources"
  type        = map(string)
  default     = {}
}
