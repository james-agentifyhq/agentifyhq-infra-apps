.PHONY: help validate build diff sync

# Default target
help:
	@echo "Infrastructure Applications Makefile"
	@echo ""
	@echo "Usage:"
	@echo "  make validate              - Validate all Kustomize configurations"
	@echo "  make validate-n8n-dev      - Validate n8n dev overlay"
	@echo "  make validate-n8n-staging  - Validate n8n staging overlay"
	@echo "  make validate-n8n-prod     - Validate n8n prod overlay"
	@echo "  make validate-dev-ns       - Validate dev-namespace overlay"
	@echo ""
	@echo "  make build-n8n-dev         - Build n8n dev manifests"
	@echo "  make build-n8n-staging     - Build n8n staging manifests"
	@echo "  make build-n8n-prod        - Build n8n prod manifests"
	@echo "  make build-dev-ns          - Build dev-namespace manifests"
	@echo ""
	@echo "  make diff-n8n-dev          - Show diff for n8n dev"
	@echo "  make diff-n8n-staging      - Show diff for n8n staging"
	@echo "  make diff-n8n-prod         - Show diff for n8n prod"
	@echo "  make diff-dev-ns           - Show diff for dev-namespace"
	@echo ""
	@echo "  make sync-n8n-dev          - Sync n8n dev application"
	@echo "  make sync-n8n-staging      - Sync n8n staging application"
	@echo "  make sync-n8n-prod         - Sync n8n prod application"
	@echo "  make sync-dev-ns           - Sync dev-namespace application"
	@echo ""
	@echo "  make list-apps             - List all ArgoCD applications"
	@echo "  make app-status            - Show status of all applications"

# Validation targets
validate: validate-n8n-dev validate-n8n-staging validate-n8n-prod validate-dev-ns
	@echo "All validations passed!"

validate-n8n-dev:
	@echo "Validating n8n dev overlay..."
	@kubectl kustomize n8n/overlays/dev > /dev/null
	@echo "✓ n8n dev overlay is valid"

validate-n8n-staging:
	@echo "Validating n8n staging overlay..."
	@kubectl kustomize n8n/overlays/staging > /dev/null
	@echo "✓ n8n staging overlay is valid"

validate-n8n-prod:
	@echo "Validating n8n prod overlay..."
	@kubectl kustomize n8n/overlays/prod > /dev/null
	@echo "✓ n8n prod overlay is valid"

validate-dev-ns:
	@echo "Validating dev-namespace overlay..."
	@kubectl kustomize dev-namespace/overlays/dev > /dev/null
	@echo "✓ dev-namespace overlay is valid"

# Build targets
build-n8n-dev:
	@kubectl kustomize n8n/overlays/dev

build-n8n-staging:
	@kubectl kustomize n8n/overlays/staging

build-n8n-prod:
	@kubectl kustomize n8n/overlays/prod

build-dev-ns:
	@kubectl kustomize dev-namespace/overlays/dev

# Diff targets (requires argocd CLI)
diff-n8n-dev:
	@argocd app diff n8n-dev

diff-n8n-staging:
	@argocd app diff n8n-staging

diff-n8n-prod:
	@argocd app diff n8n-prod

diff-dev-ns:
	@argocd app diff dev-namespace

# Sync targets (requires argocd CLI)
sync-n8n-dev:
	@argocd app sync n8n-dev

sync-n8n-staging:
	@argocd app sync n8n-staging

sync-n8n-prod:
	@argocd app sync n8n-prod

sync-dev-ns:
	@argocd app sync dev-namespace

# ArgoCD management
list-apps:
	@kubectl get applications -n argocd

app-status:
	@echo "=== n8n-dev ==="
	@argocd app get n8n-dev --show-operation || echo "Not available"
	@echo ""
	@echo "=== n8n-staging ==="
	@argocd app get n8n-staging --show-operation || echo "Not available"
	@echo ""
	@echo "=== n8n-prod ==="
	@argocd app get n8n-prod --show-operation || echo "Not available"
	@echo ""
	@echo "=== dev-namespace ==="
	@argocd app get dev-namespace --show-operation || echo "Not available"

# Apply ArgoCD applications (bootstrap)
bootstrap:
	@echo "Applying ArgoCD applications..."
	@kubectl apply -f argocd-apps/
	@echo "Applications created. Use 'make list-apps' to view status."

# Clean up (dry-run by default for safety)
clean-dry-run:
	@echo "This would delete the following applications:"
	@kubectl get applications -n argocd -l repo=infrastructure-apps

clean:
	@echo "WARNING: This will delete all applications managed by this repository!"
	@read -p "Are you sure? [y/N] " -n 1 -r; \
	echo; \
	if [[ $$REPLY =~ ^[Yy]$$ ]]; then \
		kubectl delete -f argocd-apps/; \
	fi