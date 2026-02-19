# Configuration

## Environment Variables (`.env`)

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `HCLOUD_TOKEN` | Yes | — | Hetzner Cloud API token |
| `ACME_EMAIL` | Yes | — | Email for Let's Encrypt |
| `GRAFANA_ADMIN_PASSWORD` | No | auto-generated | Grafana admin password |
| `DNS_PROVIDER` | No | `cloudflare` | DNS provider for external-dns |
| `CF_API_TOKEN` | No | — | Cloudflare API token |
| `HETZNER_DNS_TOKEN` | No | — | Hetzner DNS API token |
| `GITHUB_CLIENT_ID` | No | — | GitHub OAuth for Dex OIDC |
| `GITHUB_CLIENT_SECRET` | No | — | GitHub OAuth for Dex OIDC |

## Terraform Variables (`terraform.tfvars`)

### Server Types

| Type | vCPU | RAM | Disk | EUR/month |
|------|------|-----|------|-----------|
| `cpx11` | 2 | 2 GB | 40 GB | €4.49 |
| `cpx21` | 3 | 4 GB | 80 GB | €8.49 |
| `cpx31` | 4 | 8 GB | 160 GB | €15.49 |
| `cpx41` | 8 | 16 GB | 240 GB | €28.49 |
| `cpx51` | 16 | 32 GB | 360 GB | €54.49 |

### Multi-Zone HA

Spread control-plane nodes across datacenters for zone-level fault tolerance:

```hcl
control_plane_locations = ["nbg1", "fsn1", "hel1"]
```

!!! warning
    All locations must be within the same `network_zone` (e.g., `eu-central`).
    Cross-zone etcd latency is higher — test before using in production.
