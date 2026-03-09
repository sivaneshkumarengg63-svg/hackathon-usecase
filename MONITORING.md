# Monitoring and Logging Setup

## Cloud Logging

### View Application Logs
```bash
# View all container logs
gcloud logging read "resource.type=k8s_container" --limit 50 --format json

# View logs for specific service
gcloud logging read "resource.type=k8s_container AND resource.labels.container_name=patient-service" --limit 20

# Stream logs in real-time
gcloud logging tail "resource.type=k8s_container"

# View logs with kubectl
kubectl logs -l app=patient-service --tail=100
kubectl logs -f deployment/patient-service
```

### Create Log-Based Metrics
```bash
# Create metric for error count
gcloud logging metrics create error_count \
    --description="Count of error logs" \
    --log-filter='severity>=ERROR'
```

## Cloud Monitoring

### View Metrics in Console
1. Go to GCP Console > Monitoring
2. Navigate to Dashboards > GKE
3. Select your cluster: microservices-cluster

### Create Alerts
```bash
# Create alert policy for high CPU usage
gcloud alpha monitoring policies create \
    --notification-channels=CHANNEL_ID \
    --display-name="High CPU Usage" \
    --condition-display-name="CPU > 80%" \
    --condition-threshold-value=0.8 \
    --condition-threshold-duration=300s
```

### Custom Metrics
Add to your application code:
```javascript
// Node.js example
const { MetricServiceClient } = require('@google-cloud/monitoring');
const client = new MetricServiceClient();

async function writeMetric(value) {
  const projectId = await client.getProjectId();
  const dataPoint = {
    interval: {
      endTime: {
        seconds: Date.now() / 1000,
      },
    },
    value: {
      doubleValue: value,
    },
  };
  
  const timeSeriesData = {
    metric: {
      type: 'custom.googleapis.com/my_metric',
    },
    resource: {
      type: 'k8s_pod',
      labels: {
        project_id: projectId,
      },
    },
    points: [dataPoint],
  };
  
  const request = {
    name: client.projectPath(projectId),
    timeSeries: [timeSeriesData],
  };
  
  await client.createTimeSeries(request);
}
```

## Prometheus & Grafana Setup

### Install Prometheus Stack
```bash
# Add Helm repo
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

# Create namespace
kubectl create namespace monitoring

# Install Prometheus and Grafana
helm install prometheus prometheus-community/kube-prometheus-stack \
    --namespace monitoring \
    --set prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues=false

# Wait for pods to be ready
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=grafana -n monitoring --timeout=300s
```

### Access Grafana
```bash
# Get Grafana password
kubectl get secret -n monitoring prometheus-grafana -o jsonpath="{.data.admin-password}" | base64 --decode

# Port forward to access Grafana
kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80

# Open browser to http://localhost:3000
# Username: admin
# Password: (from above command)
```

### Configure Service Monitors
```yaml
# service-monitor.yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: microservices-monitor
  namespace: monitoring
spec:
  selector:
    matchLabels:
      app: patient-service
  endpoints:
  - port: http
    interval: 30s
    path: /metrics
```

Apply:
```bash
kubectl apply -f service-monitor.yaml
```

## Grafana Dashboards

### Import Pre-built Dashboards
1. Login to Grafana (http://localhost:3000)
2. Click "+" > Import
3. Enter dashboard IDs:
   - 315: Kubernetes cluster monitoring
   - 6417: Kubernetes Pods
   - 8588: Kubernetes Deployment

### Create Custom Dashboard
1. Click "+" > Dashboard
2. Add Panel
3. Select Prometheus as data source
4. Use PromQL queries:

```promql
# CPU Usage
rate(container_cpu_usage_seconds_total{pod=~"patient-service.*"}[5m])

# Memory Usage
container_memory_usage_bytes{pod=~"patient-service.*"}

# Request Rate
rate(http_requests_total[5m])

# Error Rate
rate(http_requests_total{status=~"5.."}[5m])
```

## Log Aggregation with Loki (Optional)

### Install Loki
```bash
helm repo add grafana https://grafana.github.io/helm-charts
helm install loki grafana/loki-stack \
    --namespace monitoring \
    --set grafana.enabled=false \
    --set prometheus.enabled=false
```

### Configure Grafana to use Loki
1. In Grafana, go to Configuration > Data Sources
2. Add Loki data source
3. URL: http://loki:3100
4. Save & Test

### Query Logs
```logql
{namespace="default", app="patient-service"} |= "error"
```

## Alerting

### Prometheus Alert Rules
```yaml
# alert-rules.yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: microservices-alerts
  namespace: monitoring
spec:
  groups:
  - name: microservices
    interval: 30s
    rules:
    - alert: HighErrorRate
      expr: rate(http_requests_total{status=~"5.."}[5m]) > 0.05
      for: 5m
      labels:
        severity: warning
      annotations:
        summary: "High error rate detected"
        description: "Error rate is {{ $value }} for {{ $labels.pod }}"
    
    - alert: PodDown
      expr: up{job="kubernetes-pods"} == 0
      for: 5m
      labels:
        severity: critical
      annotations:
        summary: "Pod is down"
        description: "{{ $labels.pod }} has been down for 5 minutes"
```

Apply:
```bash
kubectl apply -f alert-rules.yaml
```

## Useful Commands

```bash
# Check Prometheus targets
kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090
# Open http://localhost:9090/targets

# View Prometheus rules
kubectl get prometheusrules -n monitoring

# Check service monitors
kubectl get servicemonitors -n monitoring

# View logs from all services
kubectl logs -l app=patient-service --all-containers=true --tail=100

# Get metrics from Kubernetes API
kubectl top nodes
kubectl top pods

# Export Grafana dashboards
kubectl exec -n monitoring deployment/prometheus-grafana -- \
    grafana-cli admin export-dashboard <dashboard-id>
```

## Best Practices

1. **Set up alerts for**:
   - High CPU/Memory usage (>80%)
   - Pod restarts
   - High error rates (>5%)
   - Slow response times (>1s)

2. **Log retention**:
   - Configure log retention in Cloud Logging (default: 30 days)
   - Archive important logs to Cloud Storage

3. **Dashboard organization**:
   - Create separate dashboards for each service
   - Include SLI/SLO metrics
   - Add business metrics

4. **Cost optimization**:
   - Use log sampling for high-volume logs
   - Set appropriate metric retention periods
   - Use log exclusion filters for noisy logs
