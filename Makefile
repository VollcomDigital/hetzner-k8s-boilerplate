.PHONY: help setup plan apply deploy destroy kubeconfig \
       ccm csi ingress cert-manager monitoring logging argocd security \
       external-secrets external-dns autoscaler upgrade-controller \
       velero hubble upgrade \
       fmt validate lint clean nodes pods status

SHELL := /bin/bash
TERRAFORM_DIR := terraform
KUBECONFIG := $(CURDIR)/kubeconfig.yaml

export KUBECONFIG

# ============================================================================
# Help
# ============================================================================

help: ## Show this help
	@echo ""
	@echo "Hetzner Kubernetes Boilerplate"
	@echo "=============================="
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-22s\033[0m %s\n", $$1, $$2}'
	@echo ""

# ============================================================================
# Infrastructure
# ============================================================================

setup: ## Run pre-flight checks
	@bash scripts/setup.sh

init: ## Initialize Terraform
	cd $(TERRAFORM_DIR) && terraform init -upgrade

plan: init ## Preview infrastructure changes
	cd $(TERRAFORM_DIR) && terraform plan

apply: init ## Apply infrastructure changes
	cd $(TERRAFORM_DIR) && terraform apply

deploy: ## Full deployment (core infra + k8s components)
	@bash scripts/deploy.sh

deploy-all: ## Full deployment with ALL optional components
	@bash scripts/deploy.sh --all

destroy: ## Destroy all infrastructure (DANGEROUS)
	@bash scripts/destroy.sh

# ============================================================================
# Core Components
# ============================================================================

ccm: ## Deploy Hetzner Cloud Controller Manager
	kubectl apply -k kubernetes/core/hcloud-ccm/

csi: ## Deploy Hetzner CSI Driver + Storage Classes
	kubectl apply -k kubernetes/core/hcloud-csi/
	kubectl apply -f kubernetes/core/hcloud-csi/storage-classes.yaml

ingress: ## Deploy NGINX Ingress Controller
	@bash kubernetes/ingress/nginx/install.sh

cert-manager: ## Deploy cert-manager with Let's Encrypt
	@bash kubernetes/ingress/cert-manager/install.sh

# ============================================================================
# Observability
# ============================================================================

monitoring: ## Deploy Prometheus + Grafana monitoring stack
	@bash kubernetes/monitoring/install.sh

logging: ## Deploy Loki + Promtail logging stack
	@bash kubernetes/logging/install.sh

hubble: ## Deploy Hubble UI with Ingress and basic-auth
	@bash kubernetes/core/hubble-install.sh

grafana-ingress: ## Apply Grafana + Alertmanager Ingress manifests
	kubectl apply -f kubernetes/monitoring/grafana-ingress.yaml

# ============================================================================
# Security
# ============================================================================

security: ## Apply network policies, RBAC, quotas, priority classes
	kubectl apply -f kubernetes/security/priority-classes.yaml
	kubectl apply -f kubernetes/security/pod-security.yaml
	kubectl apply -f kubernetes/security/resource-quotas.yaml 2>/dev/null || true
	kubectl apply -f kubernetes/security/network-policies/
	kubectl apply -f kubernetes/security/rbac/

external-secrets: ## Deploy External Secrets Operator
	@bash kubernetes/security/external-secrets/install.sh

# ============================================================================
# System & Operations
# ============================================================================

argocd: ## Deploy ArgoCD for GitOps
	@bash kubernetes/gitops/argocd/install.sh

velero: ## Deploy Velero backup system
	@bash kubernetes/backup/velero/install.sh

external-dns: ## Deploy external-dns for automatic DNS management
	@bash kubernetes/system/external-dns/install.sh

autoscaler: ## Deploy Hetzner Cluster Autoscaler
	@bash kubernetes/system/autoscaler/install.sh

upgrade-controller: ## Deploy k3s System Upgrade Controller
	@bash kubernetes/system/upgrade-controller/install.sh

upgrade: ## Rolling k3s upgrade (usage: make upgrade VERSION=v1.30.2+k3s1)
	@bash scripts/upgrade.sh $(VERSION)

# ============================================================================
# Utilities
# ============================================================================

kubeconfig: ## Fetch kubeconfig from first control-plane node
	@FIRST_CP=$$(cd $(TERRAFORM_DIR) && terraform output -json control_plane_ips | jq -r '.[0]'); \
	SSH_KEY=$$(cd $(TERRAFORM_DIR) && terraform output -raw ssh_command_cp | grep -oP '(?<=-i )\S+'); \
	ssh -o StrictHostKeyChecking=no -i $$SSH_KEY root@$$FIRST_CP \
		'cat /etc/rancher/k3s/k3s.yaml' | \
		sed "s|https://127.0.0.1:6443|$$(cd $(TERRAFORM_DIR) && terraform output -raw api_server_url)|g" \
		> $(KUBECONFIG); \
	chmod 600 $(KUBECONFIG); \
	echo "Kubeconfig saved to $(KUBECONFIG)"

nodes: ## List cluster nodes
	kubectl get nodes -o wide

pods: ## List all pods
	kubectl get pods -A

status: ## Cluster health overview
	@echo "=== Nodes ==="
	@kubectl get nodes -o wide
	@echo ""
	@echo "=== System Pods ==="
	@kubectl get pods -n kube-system
	@echo ""
	@echo "=== Unhealthy Pods ==="
	@kubectl get pods -A --field-selector=status.phase!=Running,status.phase!=Succeeded
	@echo ""
	@echo "=== Persistent Volumes ==="
	@kubectl get pv 2>/dev/null || true
	@echo ""
	@echo "=== Backup Status ==="
	@kubectl get backupstoragelocations -n velero 2>/dev/null || echo "  Velero not installed"

fmt: ## Format Terraform files
	cd $(TERRAFORM_DIR) && terraform fmt -recursive

validate: init ## Validate Terraform configuration
	cd $(TERRAFORM_DIR) && terraform validate

lint: fmt validate ## Run formatting and validation

clean: ## Remove local artifacts (kubeconfig, .terraform)
	rm -f kubeconfig.yaml
	rm -rf $(TERRAFORM_DIR)/.terraform
	rm -f $(TERRAFORM_DIR)/.terraform.lock.hcl
