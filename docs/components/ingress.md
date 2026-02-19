# Ingress & TLS

## NGINX Ingress Controller

```bash
make ingress
```

Automatically provisions a Hetzner Load Balancer via CCM annotations.
Configured with proxy protocol, HSTS, and security headers.

## cert-manager

```bash
make cert-manager
```

Deploys with two ClusterIssuers:

- `letsencrypt-staging` — for testing (no rate limits)
- `letsencrypt-production` — for real certificates

### Example Ingress with TLS

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: my-app
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-production
spec:
  ingressClassName: nginx
  tls:
    - hosts:
        - app.example.com
      secretName: my-app-tls
  rules:
    - host: app.example.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: my-app
                port:
                  number: 80
```

## Grafana & Alertmanager Ingress

```bash
make grafana-ingress
```

Exposes Grafana and Alertmanager with TLS. Alertmanager is protected with basic auth.
