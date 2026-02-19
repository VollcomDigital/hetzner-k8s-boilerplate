# Authentication (Dex OIDC)

## Overview

Dex is an OIDC identity broker that enables SSO for the Kubernetes API server.
Users authenticate via GitHub, Google, LDAP, or SAML instead of sharing static kubeconfigs.

## Installation

```bash
export DEX_DOMAIN="dex.example.com"
export GITHUB_CLIENT_ID="your-client-id"
export GITHUB_CLIENT_SECRET="your-client-secret"
make dex
```

## Setup Steps

1. Create a GitHub OAuth App
2. Deploy Dex
3. Configure k3s API server with OIDC flags
4. Install kubelogin on developer machines
5. Bind OIDC groups to Kubernetes RBAC roles

See full instructions in `kubernetes/system/dex/README.md`.

## RBAC Mapping

Map GitHub org teams to Kubernetes roles:

```yaml
subjects:
  - kind: Group
    name: "your-org:platform-team"  # cluster-admin
  - kind: Group
    name: "your-org:developers"     # cluster-reader
```
