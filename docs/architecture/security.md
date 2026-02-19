# Security

## Layers of Defense

### Infrastructure Layer

- **Hetzner Firewalls** — per-role ingress/egress rules
- **Private Network** — inter-node traffic never traverses public internet
- **WireGuard** — pod-to-pod encryption via Cilium
- **SSH key-only auth** — no password login

### Kubernetes Layer

- **Pod Security Standards** — `restricted` for production, `baseline` for staging
- **Network Policies** — default-deny with explicit allow rules
- **RBAC** — cluster-reader and deployer ClusterRoles
- **Resource Quotas** — per-namespace CPU/memory/pod limits
- **LimitRanges** — default container resource bounds
- **Priority Classes** — 5-tier scheduling hierarchy
- **Anonymous auth disabled** — on API server

### Secret Management

- **External Secrets Operator** — syncs secrets from Vault, AWS SM, etc.
- **cert-manager** — automated TLS certificate rotation

### Authentication

- **Dex OIDC** — SSO via GitHub, Google, LDAP, SAML
- **kubelogin** — OIDC token flow for kubectl

### Monitoring & Alerting

- **Prometheus alerts** — pre-configured rules for all components
- **Alertmanager** — routing to Slack, PagerDuty, email

## Hardening Checklist

- [ ] Restrict `ssh_allowed_cidrs` to your team's IPs
- [ ] Restrict `api_allowed_cidrs` to your office/VPN
- [ ] Configure Alertmanager receivers (Slack, PagerDuty)
- [ ] Set up Dex OIDC and disable static kubeconfig distribution
- [ ] Enable Velero backups with S3 credentials
- [ ] Apply resource quotas to all application namespaces
- [ ] Review and customize network policies per service
