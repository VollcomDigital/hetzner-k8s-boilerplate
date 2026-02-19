output "zone_id" {
  description = "Hetzner DNS zone ID"
  value       = var.manage_dns ? hetznerdns_zone.main[0].id : ""
}

output "nameservers" {
  description = "Nameservers for the DNS zone"
  value       = var.manage_dns ? hetznerdns_zone.main[0].ns : []
}
