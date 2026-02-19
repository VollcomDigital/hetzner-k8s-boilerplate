# Private Container Registry (Harbor)

## Installation

```bash
make registry
```

Deploys Harbor with:

- Ingress with TLS via cert-manager
- Persistent storage on Hetzner Volumes
- Trivy vulnerability scanning
- Weekly garbage collection
- Prometheus metrics

## Usage

```bash
# Login
docker login registry.example.com -u admin -p <password>

# Tag and push
docker tag my-app:latest registry.example.com/my-project/my-app:latest
docker push registry.example.com/my-project/my-app:latest
```

## Configure k3s to Pull from Harbor

On each node, create `/etc/rancher/k3s/registries.yaml`:

```yaml
mirrors:
  registry.example.com:
    endpoint:
      - https://registry.example.com
```

Then restart k3s: `systemctl restart k3s`
