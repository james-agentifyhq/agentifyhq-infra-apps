# n8n Workflow Automation - Deployment

This directory contains the Kubernetes manifests for deploying n8n workflow automation platform using Kustomize.

---

## Quick Links

📚 **[Full Architecture Documentation](../../docs/n8n-architecture.md)** - Detailed architecture, decisions, and rationale

🚀 **[Getting Started Guide](../../docs/GETTING-STARTED.md)** - Platform setup instructions

---

## Directory Structure

```
n8n/
├── base/                           # Base configuration (shared)
│   ├── kustomization.yaml          # Base kustomization
│   ├── namespace.yaml              # Namespace definition
│   ├── deployment.yaml             # n8n Deployment
│   ├── service.yaml                # n8n Service
│   ├── ingress.yaml                # Traefik IngressRoute
│   ├── sealed-secret.yaml          # n8n secrets (encrypted)
│   ├── postgres-statefulset.yaml  # PostgreSQL StatefulSet
│   ├── postgres-service.yaml       # PostgreSQL Service
│   ├── postgres-configmap.yaml     # PostgreSQL init script
│   └── postgres-sealed-secret.yaml # PostgreSQL secrets (encrypted)
└── overlays/                       # Environment-specific configs
    ├── dev/                        # Development environment
    │   ├── kustomization.yaml
    │   └── patches.yaml
    ├── staging/                    # Staging environment
    │   ├── kustomization.yaml
    │   └── patches.yaml
    └── prod/                       # Production environment
        ├── kustomization.yaml
        ├── patches.yaml
        ├── hpa.yaml                # Horizontal Pod Autoscaler
        └── middleware.yaml         # Extra Traefik middlewares
```

---

## Environments

| Environment | Namespace | URL | Replicas | Auto-Scaling |
|-------------|-----------|-----|----------|--------------|
| Dev | n8n-dev | https://n8n-dev.nexus.local:30443 | 1 | No |
| Staging | n8n-staging | https://n8n-staging.nexus.local:30443 | 2 | No |
| Production | n8n-prod | https://n8n-prod.nexus.local:30443 | 3-10 | Yes (HPA) |

---

## Architecture Highlights

### PostgreSQL Non-Root User Security

We implement the **non-root database user pattern** for security:

1. **Init Script**: `postgres-configmap.yaml` contains a script that runs on first PostgreSQL startup
2. **User Creation**: Creates `n8n_user` with minimal required privileges
3. **Credentials**: Separate secrets for admin (postgres) and application (n8n_user)
4. **n8n Connection**: Uses `n8n_user` credentials, not the postgres superuser

**Why?** Principle of least privilege - if n8n is compromised, attacker doesn't get database superuser access.

### Volume Permissions

n8n deployment includes a **volume-permissions init container**:

```yaml
initContainers:
- name: volume-permissions
  image: busybox:1.36
  command: ["sh", "-c", "chown -R 1000:1000 /data"]
```

**Why?** Ensures PersistentVolume has correct ownership for non-root n8n user (UID 1000).

### StatefulSet for PostgreSQL

PostgreSQL uses **StatefulSet** instead of Deployment:

**Benefits:**
- Stable network identity
- Ordered pod creation/deletion
- Persistent storage automatically provisioned
- Correct for stateful workloads

---

## Quick Operations

### View Deployment Status

```bash
# Check all pods
kubectl get pods -n n8n-prod

# Check ArgoCD sync status
argocd app get n8n-prod

# Check HPA status (prod only)
kubectl get hpa -n n8n-prod
```

### View Logs

```bash
# n8n application logs
kubectl logs -n n8n-prod -l app.kubernetes.io/name=n8n -f

# PostgreSQL logs
kubectl logs -n n8n-prod statefulset/postgres-prod -f

# Init container logs (if pod won't start)
kubectl logs -n n8n-prod <pod-name> -c volume-permissions
kubectl logs -n n8n-prod <pod-name> -c wait-for-postgres
```

### Access n8n

**Via Ingress:**
```
https://n8n-prod.nexus.local:30443
```

**Via Port-Forward:**
```bash
kubectl port-forward -n n8n-prod svc/n8n-prod 5678:80
# Access at http://localhost:5678
```

### Access PostgreSQL

```bash
# Port-forward
kubectl port-forward -n n8n-prod svc/postgres-prod 5432:5432

# Connect from local machine
psql -h localhost -U n8n_user -d n8n

# Or exec into pod
kubectl exec -it -n n8n-prod postgres-prod-0 -- psql -U n8n_user -d n8n
```

### Scale n8n

**Dev/Staging (manual):**
```bash
# Edit overlay
vim overlays/staging/patches.yaml
# Change replicas value

# Commit and push
git add . && git commit -m "Scale staging to 3" && git push

# ArgoCD auto-syncs
```

**Production (automatic):**
- HPA scales between 3-10 pods based on CPU usage (80% target)
- View status: `kubectl get hpa -n n8n-prod`

---

## Making Changes

### Update Environment Variable

```bash
# 1. Edit the overlay kustomization.yaml
vim overlays/prod/kustomization.yaml

# 2. Update configMapGenerator literals
# Example: Change N8N_LOG_LEVEL from "info" to "debug"

# 3. Commit and push
git add .
git commit -m "Enable debug logging in prod"
git push origin main

# 4. ArgoCD syncs automatically
argocd app get n8n-prod
```

### Update Resource Limits

```bash
# 1. Edit overlay patches
vim overlays/prod/patches.yaml

# 2. Update resources section
# Example: Increase memory limit to 2Gi

# 3. Commit and push (same as above)
```

### Update Image Version

```bash
# 1. Edit base deployment
vim base/deployment.yaml

# 2. Change image tag from :latest to specific version
# image: n8nio/n8n:1.15.0

# 3. Commit and push
# This affects all environments
```

---

## Secrets Management

### Sealed Secrets

All sensitive data is encrypted using Sealed Secrets:

- **n8n secrets**: `base/sealed-secret.yaml` - n8n encryption keys, API tokens
- **PostgreSQL secrets**: `base/postgres-sealed-secret.yaml` - DB credentials

### Viewing Decrypted Secrets

```bash
# In cluster only (sealed-secrets controller decrypts)
kubectl get secret n8n-secrets-prod -n n8n-prod -o yaml
kubectl get secret postgres-secret-prod -n n8n-prod -o yaml
```

### Rotating Secrets

See [Architecture Documentation - Operational Procedures](../../docs/n8n-architecture.md#rotating-secrets) for detailed steps.

---

## Troubleshooting

### Pod Won't Start

```bash
# 1. Check pod status
kubectl describe pod -n n8n-prod <pod-name>

# 2. Check init containers
kubectl logs -n n8n-prod <pod-name> -c volume-permissions
kubectl logs -n n8n-prod <pod-name> -c wait-for-postgres

# 3. Check events
kubectl get events -n n8n-prod --sort-by='.lastTimestamp'
```

### Database Connection Error

```bash
# 1. Verify PostgreSQL is running
kubectl get pods -n n8n-prod -l app.kubernetes.io/name=postgres

# 2. Check PostgreSQL logs
kubectl logs -n n8n-prod statefulset/postgres-prod

# 3. Test connectivity from n8n pod
kubectl exec -it -n n8n-prod <n8n-pod> -- nc -zv postgres-prod 5432

# 4. Verify secrets match
kubectl get secret postgres-secret-prod -n n8n-prod -o yaml
```

### ArgoCD Sync Failed

```bash
# 1. Check application status
argocd app get n8n-prod

# 2. View sync difference
argocd app diff n8n-prod

# 3. Check for Kustomize errors
kubectl kustomize overlays/prod

# 4. Force sync if needed
argocd app sync n8n-prod --force
```

---

## Monitoring

### Metrics

n8n pods expose metrics for Prometheus:

```yaml
annotations:
  prometheus.io/scrape: "true"
  prometheus.io/port: "5678"
  prometheus.io/path: "/metrics"
```

### Grafana Dashboards

- **n8n Application**: Custom dashboard for workflow metrics
- **PostgreSQL**: Standard Postgres exporter dashboard
- **Pod Resources**: Kubernetes compute resources

### Logs (Grafana Loki)

Query examples:
```
# All n8n logs
{namespace="n8n-prod", app="n8n"}

# Errors only
{namespace="n8n-prod"} |= "ERROR"

# Workflow execution
{namespace="n8n-prod"} |~ "workflow|execution"
```

---

## Key Differences from Official n8n-hosting

We adopted and improved upon the [official n8n-hosting repository](https://github.com/n8n-io/n8n-kubernetes-hosting):

### ✅ What We Adopted
- Non-root PostgreSQL user pattern
- Volume permissions init container
- Database initialization script approach

### 🚀 What We Improved
- **StatefulSet** for PostgreSQL (not Deployment)
- **PostgreSQL 16** (not version 11)
- **Security contexts** on all containers
- **Health probes** (liveness, readiness, startup)
- **GitOps** with ArgoCD
- **Multi-environment** support
- **HPA** for auto-scaling
- **Production-grade** resource management

See [full comparison in architecture docs](../../docs/n8n-architecture.md#comparison-with-official-n8n-hosting).

---

## Security

### Implemented Security Features

- ✅ All containers run as non-root
- ✅ Read-only root filesystems (where possible)
- ✅ Minimal Linux capabilities
- ✅ Seccomp profiles
- ✅ Non-root database user
- ✅ Encrypted secrets in Git (Sealed Secrets)
- ✅ TLS on all ingress
- ✅ Resource limits (prevent DoS)

### Security Best Practices

1. **Never commit unsealed secrets** to Git
2. **Rotate database passwords** quarterly
3. **Update images** regularly for security patches
4. **Review RBAC** permissions periodically
5. **Monitor logs** for suspicious activity

---

## Support

### Documentation
- 📚 [Full Architecture Documentation](../../docs/n8n-architecture.md)
- 🔧 [Operational Procedures](../../docs/n8n-architecture.md#operational-procedures)
- 🐛 [Troubleshooting Guide](../../docs/n8n-architecture.md#troubleshooting)

### Getting Help
- Check ArgoCD UI for sync status
- Review application logs
- Check Kubernetes events
- Consult architecture documentation

---

**Maintained by:** Infrastructure Team
**Last Updated:** 2025-10-01
