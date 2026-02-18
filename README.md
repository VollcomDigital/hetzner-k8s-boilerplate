# Hetzner Kubernetes Boilerplate

Production-ready Kubernetes cluster boilerplate for [Hetzner Cloud](https://www.hetzner.com/cloud), following industry best practices.

## Quick Links

- **[Planning Document](docs/PLANNING.md)** — Full architecture, stack decisions, and implementation roadmap
- **Stack:** k3s • Terraform • Ansible • hcloud CCM/CSI • Flux/Argo CD • Prometheus/Grafana

## Overview

| Layer | Technology |
|-------|------------|
| **Cluster** | k3s (lightweight, certified K8s) |
| **IaC** | Terraform (Hetzner) + Ansible (bootstrap) |
| **Cloud Integration** | hcloud-cloud-controller-manager, csi-driver-hcloud |
| **GitOps** | Flux or Argo CD |
| **Ingress** | Traefik / NGINX + cert-manager |
| **Observability** | Prometheus, Grafana, Loki |

## Getting Started

*Implementation in progress. See [docs/PLANNING.md](docs/PLANNING.md) for the full roadmap.*