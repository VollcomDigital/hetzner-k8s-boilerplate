# Optional: Hetzner DNS management
# Enable by setting var.manage_dns = true and providing dns_zone + records.
# Requires a Hetzner DNS API token (separate from the Cloud token).
#
# Provider: https://registry.terraform.io/providers/hetznercloud/hcloud
# Note: Hetzner DNS uses a different API. This module uses the
# timohirt/hetznerdns community provider.

terraform {
  required_providers {
    hetznerdns = {
      source  = "timohirt/hetznerdns"
      version = "~> 2.2"
    }
  }
}

resource "hetznerdns_zone" "main" {
  count = var.manage_dns ? 1 : 0
  name  = var.dns_zone
  ttl   = var.default_ttl
}

resource "hetznerdns_record" "records" {
  for_each = var.manage_dns ? var.dns_records : {}

  zone_id = hetznerdns_zone.main[0].id
  name    = each.value.name
  value   = each.value.value
  type    = each.value.type
  ttl     = lookup(each.value, "ttl", var.default_ttl)
}

resource "hetznerdns_record" "wildcard_ingress" {
  count = var.manage_dns && var.ingress_lb_ipv4 != "" ? 1 : 0

  zone_id = hetznerdns_zone.main[0].id
  name    = "*"
  value   = var.ingress_lb_ipv4
  type    = "A"
  ttl     = 300
}
