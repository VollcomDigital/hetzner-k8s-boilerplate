# DNS Module (Optional)

This module manages DNS zones and records via the [Hetzner DNS API](https://dns.hetzner.com/api-docs).

**This module is NOT included in the root Terraform configuration by default.**  
It is provided as a standalone utility for users who manage DNS through Hetzner.

Most users will prefer Cloudflare or another DNS provider with the `external-dns`
Kubernetes controller, which auto-creates DNS records from Ingress resources.

## Usage

To use this module, add the following to your `terraform/main.tf`:

```hcl
provider "hetznerdns" {
  apitoken = var.hetzner_dns_token
}

module "dns" {
  source = "./modules/dns"

  manage_dns       = true
  dns_zone         = "example.com"
  ingress_lb_ipv4  = ""  # Set after ingress LB is provisioned

  dns_records = {
    api = {
      name  = "api"
      value = hcloud_load_balancer.api_pre.ipv4
      type  = "A"
    }
    grafana = {
      name  = "grafana"
      value = "INGRESS_LB_IP"
      type  = "A"
    }
  }
}
```

Add the variable to `variables.tf`:

```hcl
variable "hetzner_dns_token" {
  description = "Hetzner DNS API token (separate from Cloud token)"
  type        = string
  sensitive   = true
  default     = ""
}
```

And to `terraform.tfvars`:

```hcl
hetzner_dns_token = "YOUR_HETZNER_DNS_API_TOKEN"
```
