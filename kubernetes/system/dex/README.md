# Dex OIDC Authentication

Dex is an OIDC identity broker that enables SSO for the Kubernetes API server.
Users authenticate via GitHub, Google, LDAP, or SAML instead of sharing static kubeconfigs.

## Prerequisites

1. A domain pointing to the Ingress LB (e.g., `dex.example.com`)
2. A GitHub OAuth App (or other IdP credentials)
3. cert-manager deployed for TLS

## Setup

### 1. Create a GitHub OAuth App

- Go to: https://github.com/settings/applications/new
- **Homepage URL**: `https://dex.example.com`
- **Authorization callback URL**: `https://dex.example.com/callback`
- Note the Client ID and Client Secret

### 2. Deploy Dex

```bash
export DEX_DOMAIN="dex.example.com"
export GITHUB_CLIENT_ID="your-client-id"
export GITHUB_CLIENT_SECRET="your-client-secret"
make dex
```

### 3. Configure k3s API Server for OIDC

Add these flags to the k3s server configuration on each control-plane node.

Edit `/etc/rancher/k3s/config.yaml` and add under `kube-apiserver-arg`:

```yaml
kube-apiserver-arg:
  - "oidc-issuer-url=https://dex.example.com"
  - "oidc-client-id=kubernetes"
  - "oidc-username-claim=email"
  - "oidc-groups-claim=groups"
```

Then restart k3s: `systemctl restart k3s`

Alternatively, set these in `terraform/cloud-init/control-plane.yaml.tftpl` before
initial deployment to avoid post-deploy SSH.

### 4. Install kubelogin

```bash
# macOS
brew install int128/kubelogin/kubelogin

# Linux
curl -LO https://github.com/int128/kubelogin/releases/latest/download/kubelogin_linux_amd64.zip
unzip kubelogin_linux_amd64.zip -d /usr/local/bin/
```

### 5. Configure kubectl

```bash
kubectl oidc-login setup \
  --oidc-issuer-url=https://dex.example.com \
  --oidc-client-id=kubernetes \
  --oidc-client-secret=<secret-from-install-output>
```

### 6. Bind OIDC Groups to Roles

```bash
kubectl apply -f kubernetes/system/dex/rbac.yaml
```

Edit the file to map your GitHub org teams to Kubernetes RBAC roles.
