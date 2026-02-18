variable "cluster_name" {
  type = string
}

variable "location" {
  type = string
}

variable "lb_type" {
  type = string
}

variable "network_id" {
  type = number
}

variable "control_plane_server_ids" {
  description = "Server IDs of control plane nodes to attach as targets"
  type        = list(number)
}

variable "labels" {
  type    = map(string)
  default = {}
}
