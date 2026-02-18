.PHONY: help setup plan apply deploy destroy kubeconfig \
       ccm csi ingress cert-manager monitoring argocd security \
       fmt validate lint clean

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
		awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-18s\033[0m %s\n", $$1, $$2}'
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

deploy: ## Full deployment (infra + k8s components)
	@bash scripts/deploy.sh

destroy: ## Destroy all infrastructure (DANGEROUS)
	@bash scripts/destroy.sh

# ============================================================================
# Kubernetes Components
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

monitoring: ## Deploy Prometheus + Grafana monitoring stack
	@bash kubernetes/monitoring/install.sh

argocd: ## Deploy ArgoCD for GitOps
	@bash kubernetes/gitops/argocd/install.sh

security: ## Apply network policies and RBAC templates
	kubectl apply -f kubernetes/security/network-policies/
	kubectl apply -f kubernetes/security/rbac/
	kubectl apply -f kubernetes/security/pod-security.yaml

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
	@echo "=== All Namespaces ==="
	@kubectl get pods -A --field-selector=status.phase!=Running,status.phase!=Succeeded

fmt: ## Format Terraform files
	cd $(TERRAFORM_DIR) && terraform fmt -recursive

validate: init ## Validate Terraform configuration
	cd $(TERRAFORM_DIR) && terraform validate

lint: fmt validate ## Run formatting and validation

clean: ## Remove local artifacts (kubeconfig, .terraform)
	rm -f kubeconfig.yaml
	rm -rf $(TERRAFORM_DIR)/.terraform
	rm -f $(TERRAFORM_DIR)/.terraform.lock.hcl
