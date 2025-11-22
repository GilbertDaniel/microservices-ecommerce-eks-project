# ArgoCD Setup Guide

This guide covers installing and configuring ArgoCD on your EKS cluster after provisioning.

## Prerequisites

- EKS cluster provisioned and running
- `kubectl` configured to access your EKS cluster
- Access to jumphost EC2 or local machine with cluster credentials

## Installation Steps

### 1. Create ArgoCD Namespace

```bash
kubectl create namespace argocd
```

### 2. Install ArgoCD

```bash
kubectl apply -n argocd \
  -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
```

### 3. Verify Installation

Wait for all pods to be in `Running` state:

```bash
kubectl get pods -n argocd
```

Check all ArgoCD resources:

```bash
kubectl get all -n argocd
```

### 4. Expose ArgoCD Server

Change the service type from `ClusterIP` to `LoadBalancer`:

```bash
kubectl patch svc argocd-server -n argocd -p '{"spec": {"type": "LoadBalancer"}}'
```

Get the LoadBalancer URL:

```bash
kubectl get svc argocd-server -n argocd
```

### 5. Get Initial Admin Password

Retrieve the auto-generated admin password:

```bash
kubectl get secret argocd-initial-admin-secret -n argocd \
  -o jsonpath="{.data.password}" | base64 -d && echo
```

### 6. Access ArgoCD UI

- **URL**: Use the EXTERNAL-IP from step 4 (LoadBalancer DNS)
- **Username**: `admin`
- **Password**: Output from step 5

## Create Application Namespace

Create the namespace where your applications will be deployed:

```bash
kubectl create namespace dev
kubectl get namespaces
```

## Next Steps

After ArgoCD is installed and accessible:

1. Login to ArgoCD UI
2. Connect your Git repository
3. Create ArgoCD applications for your microservices
4. Configure sync policies (automatic or manual)
5. (Optional) Configure Route 53 for custom domain

## Useful Commands

```bash
# View ArgoCD applications
kubectl get applications -n argocd

# Sync an application manually
argocd app sync <app-name>

# View application status
argocd app get <app-name>

# Delete ArgoCD (if needed)
kubectl delete -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
kubectl delete namespace argocd
```

## Troubleshooting

**Pods not running?**
```bash
kubectl describe pod <pod-name> -n argocd
kubectl logs <pod-name> -n argocd
```

**Can't access LoadBalancer?**
- Ensure security group allows inbound traffic on ports 80/443
- Verify LoadBalancer is created: `kubectl get svc -n argocd`

**Forgot admin password?**
```bash
# Reset by deleting the secret (will regenerate)
kubectl delete secret argocd-initial-admin-secret -n argocd
# Restart argocd-server pod to generate new password
kubectl rollout restart deployment argocd-server -n argocd
```