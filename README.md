# Infrastructure Applications Repository

This repository contains Kustomize-based application deployments managed by ArgoCD in a GitOps workflow.

## Overview

This repository follows GitOps principles where:
- All application configurations are stored as code
- ArgoCD automatically syncs applications from this repository
- Changes to applications are made via Git commits
- Environment-specific configurations use Kustomize overlays

## Repository Structure

```
infrastructure-apps/
├── n8n/                    # n8n workflow automation platform
│   ├── base/               # Base manifests
│   └── overlays/           # Environment-specific overlays
│       ├── dev/
│       ├── staging/
│       └── prod/
├── dev-namespace/          # Development namespace configuration
│   ├── base/
│   └── overlays/
│       └── dev/
└── argocd-apps/            # ArgoCD Application definitions
```

## Applications

### n8n - Workflow Automation
- **Base**: Core n8n deployment with PostgreSQL backend
- **Dev**: 1 replica, reduced resources
- **Staging**: 2 replicas, medium resources
- **Prod**: 3 replicas, HPA enabled, high resources

### dev-namespace - Development Tools
- Dedicated namespace for development workloads
- Resource quotas and network policies

## GitOps Workflow

### Making Changes

1. **Create a feature branch**
   ```bash
   git checkout -b feature/update-n8n
   ```

2. **Make your changes**
   ```bash
   # Edit the relevant overlay files
   vim n8n/overlays/prod/patches.yaml
   ```

3. **Test locally** (optional)
   ```bash
   make validate-n8n-prod
   ```

4. **Commit and push**
   ```bash
   git add .
   git commit -m "Update n8n prod replica count to 5"
   git push origin feature/update-n8n
   ```

5. **Create Pull Request**
   - ArgoCD will detect the change once merged to main
   - Auto-sync will deploy the changes (if enabled)

### Viewing Application Status

```bash
# View all applications
kubectl get applications -n argocd

# View specific application
kubectl get application n8n-prod -n argocd -o yaml

# Check application sync status
argocd app get n8n-prod
```

### Manual Sync

If auto-sync is disabled, manually sync applications:

```bash
argocd app sync n8n-prod
```

## Kustomize Overlays

Overlays allow environment-specific customization without duplicating base configurations:

- **base/**: Common configuration shared across all environments
- **overlays/dev/**: Development environment (lower resources, 1 replica)
- **overlays/staging/**: Staging environment (medium resources, 2 replicas)
- **overlays/prod/**: Production environment (high resources, HPA, 3+ replicas)

### Building Overlays Locally

```bash
# Build and view the dev overlay
kubectl kustomize n8n/overlays/dev

# Build and view the prod overlay
kubectl kustomize n8n/overlays/prod
```

## Secrets Management

Secrets are managed using Sealed Secrets:

1. **Create a secret**
   ```bash
   kubectl create secret generic db-credentials \
     --from-literal=username=n8n \
     --from-literal=password=changeme \
     --dry-run=client -o yaml > secret.yaml
   ```

2. **Seal the secret**
   ```bash
   kubeseal --format yaml < secret.yaml > sealed-secret.yaml
   ```

3. **Commit sealed secret**
   ```bash
   git add sealed-secret.yaml
   git commit -m "Add database credentials"
   ```

## Makefile Commands

```bash
# Validate all applications
make validate

# Validate specific application
make validate-n8n-prod

# Build overlay
make build-n8n-prod

# Show diff between current state and Git
make diff-n8n-prod
```

## Application Management

### Adding a New Application

1. Create directory structure:
   ```bash
   mkdir -p myapp/{base,overlays/{dev,prod}}
   ```

2. Create base manifests in `myapp/base/`

3. Create overlays in `myapp/overlays/*/`

4. Create ArgoCD Application in `argocd-apps/myapp-{env}.yaml`

5. Commit and push changes

### Updating an Application

1. Modify the relevant overlay files
2. Test with `kubectl kustomize`
3. Commit and push
4. ArgoCD will sync automatically (or manually sync)

### Rolling Back

```bash
# View history
argocd app history n8n-prod

# Rollback to previous version
argocd app rollback n8n-prod <revision>
```

## Best Practices

1. **Never commit unencrypted secrets** - Always use Sealed Secrets
2. **Use overlays for environment differences** - Keep base configuration generic
3. **Test locally before pushing** - Use `kubectl kustomize` to validate
4. **Write descriptive commit messages** - They appear in ArgoCD sync history
5. **Use resource limits** - Prevent applications from consuming excessive resources
6. **Enable health checks** - Ensure applications are monitored properly
7. **Use network policies** - Restrict traffic between applications
8. **Tag images properly** - Avoid `:latest` tag in production

## Monitoring

### ArgoCD UI
Access the ArgoCD UI to view application status, sync history, and resource health:
```
https://argocd.example.com
```

### Metrics
- Application sync status
- Resource health status
- Deployment history
- Sync failures and errors

## Troubleshooting

### Application Out of Sync

```bash
# Check what's different
argocd app diff n8n-prod

# Force sync
argocd app sync n8n-prod --force
```

### Application Degraded

```bash
# Check resource status
kubectl get all -n n8n-prod

# Check events
kubectl get events -n n8n-prod --sort-by='.lastTimestamp'

# Check logs
kubectl logs -n n8n-prod deployment/n8n
```

### Sealed Secret Issues

```bash
# Verify sealed secret controller is running
kubectl get pods -n kube-system | grep sealed-secrets

# Check sealed secret status
kubectl get sealedsecrets -n n8n-prod
```

## Support

For issues or questions:
1. Check ArgoCD application status
2. Review application logs
3. Check Kubernetes events
4. Review Git commit history for recent changes

## References

- [ArgoCD Documentation](https://argo-cd.readthedocs.io/)
- [Kustomize Documentation](https://kustomize.io/)
- [Sealed Secrets Documentation](https://github.com/bitnami-labs/sealed-secrets)
- [n8n Documentation](https://docs.n8n.io/)