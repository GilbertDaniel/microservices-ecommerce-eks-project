# Monitoring Setup Guide

This guide covers installing Prometheus and Grafana on your EKS cluster for monitoring microservices.

## Prerequisites

- EKS cluster provisioned and running
- `kubectl` configured to access your EKS cluster
- Helm 3.x installed

## What Gets Installed

The `kube-prometheus-stack` includes:
- **Prometheus** - Metrics collection and storage
- **Grafana** - Visualization dashboards
- **Alertmanager** - Alert routing and management
- **Node Exporter** - Hardware and OS metrics
- **Kube State Metrics** - Kubernetes object metrics

## Installation Steps

### 1. Create Monitoring Namespace

```bash
kubectl create namespace monitoring
```

### 2. Add Helm Repository

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
```

### 3. Install Kube Prometheus Stack

```bash
helm install kube-prom-stack prometheus-community/kube-prometheus-stack \
  --namespace monitoring
```

### 4. Verify Installation

Wait for all pods to be in `Running` state:

```bash
kubectl get pods -n monitoring
```

Check all monitoring resources:

```bash
kubectl get all -n monitoring
```

### 5. Expose Grafana UI

Change the Grafana service type to `LoadBalancer`:

```bash
kubectl patch svc kube-prom-stack-grafana -n monitoring \
  -p '{"spec": {"type": "LoadBalancer"}}'
```

Get the LoadBalancer URL:

```bash
kubectl get svc kube-prom-stack-grafana -n monitoring
```

### 6. Get Grafana Admin Credentials

**Username**: `admin`

**Password**:
```bash
kubectl get secret kube-prom-stack-grafana -n monitoring \
  -o jsonpath="{.data.admin-password}" | base64 -d && echo
```

### 7. Access Grafana Dashboard

Open your browser and navigate to the EXTERNAL-IP from step 5. Login with the credentials from step 6.

## Default Dashboards

Grafana comes pre-configured with dashboards for:
- Kubernetes cluster monitoring
- Node metrics (CPU, memory, disk)
- Pod metrics
- Persistent volumes
- Namespace overview

## Expose Prometheus (Optional)

To access Prometheus UI directly:

```bash
kubectl patch svc kube-prom-stack-kube-prome-prometheus -n monitoring \
  -p '{"spec": {"type": "LoadBalancer"}}'
kubectl get svc kube-prom-stack-kube-prome-prometheus -n monitoring
```

Access Prometheus at the EXTERNAL-IP on port 9090.

## Useful Commands

```bash
# View all monitoring services
kubectl get svc -n monitoring

# Check Prometheus targets
kubectl port-forward -n monitoring svc/kube-prom-stack-kube-prome-prometheus 9090:9090

# View Grafana logs
kubectl logs -n monitoring -l app.kubernetes.io/name=grafana

# Restart Grafana
kubectl rollout restart deployment kube-prom-stack-grafana -n monitoring
```

## Custom Metrics Integration

To monitor your microservices, ensure they expose metrics in Prometheus format:
- Add Prometheus client library to your service
- Expose metrics endpoint (typically `/metrics`)
- Create a ServiceMonitor CR to scrape your service

Example ServiceMonitor:
```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: myservice-metrics
  namespace: monitoring
spec:
  selector:
    matchLabels:
      app: myservice
  endpoints:
  - port: metrics
    interval: 30s
```

## Troubleshooting

**Pods not starting?**
```bash
kubectl describe pod <pod-name> -n monitoring
kubectl logs <pod-name> -n monitoring
```

**Can't access Grafana LoadBalancer?**
- Verify security group allows inbound traffic on port 80
- Check LoadBalancer creation: `kubectl get svc -n monitoring`

**Forgot Grafana password?**
```bash
# Reset admin password
kubectl delete secret kube-prom-stack-grafana -n monitoring
helm upgrade kube-prom-stack prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --reuse-values
```

**Remove monitoring stack:**
```bash
helm uninstall kube-prom-stack -n monitoring
kubectl delete namespace monitoring
```

## Next Steps

1. Import additional Grafana dashboards from [grafana.com/dashboards](https://grafana.com/grafana/dashboards/)
2. Configure alerting rules in Prometheus
3. Set up notification channels in Alertmanager (Slack, email, PagerDuty)
4. Create custom dashboards for your microservices
5. Configure data retention policies
