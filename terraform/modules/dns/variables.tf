variable "manage_dns" {
  description = "Whether to manage DNS records via Terraform"
  type        = bool
  default     = false
}

variable "dns_zone" {
  description = "Root DNS zone (e.g., example.com)"
  type        = string
  default     = ""
}

variable "default_ttl" {
  description = "Default TTL for DNS records (seconds)"
  type        = number
  default     = 3600
}

variable "dns_records" {
  description = "Map of DNS records to create"
  type = map(object({
    name  = string
    value = string
    type  = string
    ttl   = optional(number)
  }))
  default = {}
}

variable "ingress_lb_ipv4" {
  description = "IPv4 of the ingress LB for wildcard record"
  type        = string
  default     = ""
}
