# Testing Guide

## Local Testing (Before Deployment)

### Test Node.js Services Locally

#### Patient Service
```bash
cd patient-service
npm install
npm start

# In another terminal
curl http://localhost:3000/health
curl http://localhost:3000/patients
curl http://localhost:3000/patients/1
curl -X POST http://localhost:3000/patients \
  -H "Content-Type: application/json" \
  -d '{"name":"Test Patient","age":35,"condition":"Healthy"}'
```

#### Application Service
```bash
cd application-service
npm install
npm start

# In another terminal
curl http://localhost:3001/health
curl http://localhost:3001/appointments
curl http://localhost:3001/appointments/1
curl -X POST http://localhost:3001/appointments \
  -H "Content-Type: application/json" \
  -d '{"patientId":"1","date":"2024-01-20","time":"14:00","doctor":"Dr. Test"}'
```

#### Order Service
```bash
cd order-service
mvn spring-boot:run

# In another terminal
curl http://localhost:8080/actuator/health
```

### Test Docker Images Locally

```bash
# Build images
docker build -t patient-service:test ./patient-service
docker build -t application-service:test ./application-service
docker build -t order-service:test ./order-service

# Run containers
docker run -d -p 3000:3000 --name patient-test patient-service:test
docker run -d -p 3001:3001 --name app-test application-service:test
docker run -d -p 8080:8080 --name order-test order-service:test

# Test endpoints
curl http://localhost:3000/health
curl http://localhost:3001/health
curl http://localhost:8080/actuator/health

# Cleanup
docker stop patient-test app-test order-test
docker rm patient-test app-test order-test
```

## Terraform Testing

### Validate Configuration
```bash
cd terraform/environments/dev

# Format check
terraform fmt -check -recursive

# Initialize
terraform init

# Validate
terraform validate

# Plan (dry run)
terraform plan

# Check for security issues (optional)
# Install tfsec: https://github.com/aquasecurity/tfsec
tfsec .
```

### Test State Management
```bash
# List state
terraform state list

# Show specific resource
terraform state show google_container_cluster.primary

# Refresh state
terraform refresh
```

## Kubernetes Testing

### Pre-Deployment Validation

```bash
# Validate YAML syntax
kubectl apply --dry-run=client -f k8s/patient-service.yaml
kubectl apply --dry-run=client -f k8s/application-service.yaml
kubectl apply --dry-run=client -f k8s/order-service.yaml
kubectl apply --dry-run=client -f k8s/ingress.yaml

# Validate with server
kubectl apply --dry-run=server -f k8s/
```

### Post-Deployment Testing

#### Check Deployment Status
```bash
# Get all resources
kubectl get all

# Check deployments
kubectl get deployments
kubectl describe deployment patient-service
kubectl describe deployment application-service
kubectl describe deployment order-service

# Check pods
kubectl get pods
kubectl get pods -o wide

# Check services
kubectl get services
kubectl describe service patient-service

# Check ingress
kubectl get ingress
kubectl describe ingress microservices-ingress
```

#### Check Pod Health
```bash
# Get pod logs
kubectl logs -l app=patient-service --tail=50
kubectl logs -l app=application-service --tail=50
kubectl logs -l app=order-service --tail=50

# Stream logs
kubectl logs -f deployment/patient-service

# Check pod events
kubectl get events --sort-by=.metadata.creationTimestamp

# Execute commands in pod
kubectl exec -it <pod-name> -- /bin/sh
```

#### Test Service Connectivity
```bash
# Port forward to test services directly
kubectl port-forward service/patient-service 3000:80
kubectl port-forward service/application-service 3001:80
kubectl port-forward service/order-service 8080:80

# Test from another pod
kubectl run test-pod --image=curlimages/curl -i --tty --rm -- sh
# Inside pod:
curl http://patient-service/health
curl http://application-service/health
curl http://order-service/actuator/health
```

## Integration Testing

### Test via Ingress

```bash
# Get Ingress IP
INGRESS_IP=$(kubectl get ingress microservices-ingress -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
echo "Ingress IP: $INGRESS_IP"

# Wait for IP to be assigned (may take 5-10 minutes)
while [ -z "$INGRESS_IP" ]; do
  echo "Waiting for Ingress IP..."
  sleep 10
  INGRESS_IP=$(kubectl get ingress microservices-ingress -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
done

echo "Ingress IP assigned: $INGRESS_IP"
```

### Functional Tests

```bash
# Health checks
curl -v http://$INGRESS_IP/patients/health
curl -v http://$INGRESS_IP/appointments/health

# GET requests
curl http://$INGRESS_IP/patients
curl http://$INGRESS_IP/patients/1
curl http://$INGRESS_IP/appointments
curl http://$INGRESS_IP/appointments/1

# POST requests
curl -X POST http://$INGRESS_IP/patients \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Alice Johnson",
    "age": 28,
    "condition": "Healthy"
  }'

curl -X POST http://$INGRESS_IP/appointments \
  -H "Content-Type: application/json" \
  -d '{
    "patientId": "1",
    "date": "2024-02-15",
    "time": "09:00",
    "doctor": "Dr. Williams"
  }'

# GET by patient ID
curl http://$INGRESS_IP/appointments/patient/1
```

### Load Testing

```bash
# Install Apache Bench
# Ubuntu/Debian: apt-get install apache2-utils
# Mac: brew install httpd

# Simple load test
ab -n 1000 -c 10 http://$INGRESS_IP/patients

# More detailed test
ab -n 5000 -c 50 -g results.tsv http://$INGRESS_IP/patients

# Using hey (modern alternative)
# Install: go install github.com/rakyll/hey@latest
hey -n 1000 -c 10 http://$INGRESS_IP/patients
```

## Performance Testing

### Resource Usage
```bash
# Check node resources
kubectl top nodes

# Check pod resources
kubectl top pods

# Detailed pod metrics
kubectl describe node <node-name>
```

### Scaling Tests
```bash
# Manual scaling
kubectl scale deployment patient-service --replicas=5

# Watch scaling
kubectl get pods -w

# Check HPA (if configured)
kubectl get hpa
kubectl describe hpa patient-service-hpa
```

## CI/CD Testing

### Test GitHub Actions Locally

```bash
# Install act: https://github.com/nektos/act
# Mac: brew install act
# Linux: curl https://raw.githubusercontent.com/nektos/act/master/install.sh | sudo bash

# List workflows
act -l

# Run specific workflow
act -j terraform-validate
act -j build-and-push --secret-file .secrets

# Dry run
act -n
```

### Test Workflows in GitHub

1. Create a feature branch
2. Make a small change
3. Push and create PR
4. Verify workflows run:
   - Terraform validate
   - Terraform plan
5. Merge PR
6. Verify workflows run:
   - Terraform apply
   - Docker build
   - GKE deploy

## Monitoring Tests

### Cloud Logging
```bash
# Query logs
gcloud logging read "resource.type=k8s_container AND resource.labels.container_name=patient-service" \
  --limit 50 \
  --format json

# Stream logs
gcloud logging tail "resource.type=k8s_container"

# Search for errors
gcloud logging read "severity>=ERROR" --limit 20
```

### Cloud Monitoring
```bash
# List metrics
gcloud monitoring metrics-descriptors list --filter="metric.type:kubernetes"

# Get time series data
gcloud monitoring time-series list \
  --filter='metric.type="kubernetes.io/container/cpu/core_usage_time"'
```

### Prometheus Tests (if installed)
```bash
# Port forward to Prometheus
kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090

# Open http://localhost:9090
# Test queries:
# - up
# - rate(container_cpu_usage_seconds_total[5m])
# - container_memory_usage_bytes
```

## Security Testing

### Image Scanning
```bash
# Scan images in Artifact Registry
gcloud artifacts docker images scan \
  us-central1-docker.pkg.dev/PROJECT_ID/microservices-repo/patient-service:latest

# List vulnerabilities
gcloud artifacts docker images list-vulnerabilities \
  us-central1-docker.pkg.dev/PROJECT_ID/microservices-repo/patient-service:latest
```

### Network Policy Testing
```bash
# Test pod-to-pod communication
kubectl run test-pod --image=curlimages/curl -i --tty --rm -- sh

# Inside pod, test connectivity
curl http://patient-service/health
curl http://application-service/health
```

### RBAC Testing
```bash
# Check service account permissions
kubectl auth can-i list pods --as=system:serviceaccount:default:default

# Test with specific service account
kubectl auth can-i create deployments --as=system:serviceaccount:default:gke-sa
```

## Automated Test Script

```bash
#!/bin/bash
# test-deployment.sh

set -e

echo "=== Running Deployment Tests ==="

# Get Ingress IP
INGRESS_IP=$(kubectl get ingress microservices-ingress -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

if [ -z "$INGRESS_IP" ]; then
  echo "❌ Ingress IP not assigned"
  exit 1
fi

echo "✓ Ingress IP: $INGRESS_IP"

# Test Patient Service
echo "Testing Patient Service..."
RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" http://$INGRESS_IP/patients)
if [ "$RESPONSE" -eq 200 ]; then
  echo "✓ Patient Service: OK"
else
  echo "❌ Patient Service: FAILED (HTTP $RESPONSE)"
  exit 1
fi

# Test Application Service
echo "Testing Application Service..."
RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" http://$INGRESS_IP/appointments)
if [ "$RESPONSE" -eq 200 ]; then
  echo "✓ Application Service: OK"
else
  echo "❌ Application Service: FAILED (HTTP $RESPONSE)"
  exit 1
fi

# Check pod status
echo "Checking pod status..."
PODS_READY=$(kubectl get pods -l app=patient-service -o jsonpath='{.items[*].status.conditions[?(@.type=="Ready")].status}' | grep -o "True" | wc -l)
if [ "$PODS_READY" -ge 1 ]; then
  echo "✓ Patient Service pods: $PODS_READY ready"
else
  echo "❌ No patient service pods ready"
  exit 1
fi

echo ""
echo "=== All Tests Passed ==="
```

Make executable and run:
```bash
chmod +x test-deployment.sh
./test-deployment.sh
```

## Troubleshooting Tests

### Common Issues

#### Pods not starting
```bash
kubectl describe pod <pod-name>
kubectl logs <pod-name>
kubectl get events --field-selector involvedObject.name=<pod-name>
```

#### Image pull errors
```bash
# Check image exists
gcloud artifacts docker images list us-central1-docker.pkg.dev/PROJECT_ID/microservices-repo

# Check node can pull
kubectl debug node/<node-name> -it --image=busybox
```

#### Service not accessible
```bash
# Check endpoints
kubectl get endpoints

# Check service
kubectl describe service patient-service

# Test from within cluster
kubectl run test --image=curlimages/curl -i --rm -- curl http://patient-service/health
```

## Test Checklist

- [ ] Local services run successfully
- [ ] Docker images build without errors
- [ ] Terraform validates and plans successfully
- [ ] Kubernetes manifests are valid
- [ ] Pods are running and ready
- [ ] Services are accessible within cluster
- [ ] Ingress has external IP assigned
- [ ] All endpoints return 200 OK
- [ ] Load balancing works across replicas
- [ ] Logs are visible in Cloud Logging
- [ ] Metrics appear in Cloud Monitoring
- [ ] CI/CD pipelines execute successfully
- [ ] Health checks pass
- [ ] Resource limits are appropriate

## Continuous Testing

Set up automated testing in CI/CD:

```yaml
# Add to .github/workflows/test.yml
name: Integration Tests
on: [push, pull_request]
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Run tests
        run: ./test-deployment.sh
```
