# Quick Start Guide

## Prerequisites Checklist
- [ ] GCP account with billing enabled
- [ ] gcloud CLI installed
- [ ] Terraform >= 1.6.0 installed
- [ ] kubectl installed
- [ ] Docker installed
- [ ] Git installed
- [ ] GitHub account

## 5-Minute Setup

### 1. Initial Setup (5 minutes)
```bash
# Clone repository
git clone <your-repo-url>
cd hackathon-usecase

# Run automated setup
chmod +x setup.sh
./setup.sh
```

This script will:
- Enable required GCP APIs
- Create GCS bucket for Terraform state
- Create service account for GitHub Actions
- Generate service account key
- Update Terraform configuration

### 2. Configure GitHub (2 minutes)
1. Go to your GitHub repository
2. Navigate to Settings > Secrets and variables > Actions
3. Add secrets:
   - `GCP_PROJECT_ID`: Your GCP project ID
   - `GCP_SA_KEY`: Paste contents of `github-actions-key.json`

### 3. Deploy Infrastructure (10 minutes)
```bash
cd terraform/environments/dev
terraform init
terraform apply -auto-approve
```

### 4. Build and Deploy (5 minutes)
```bash
# Return to root directory
cd ../../..

# Build and push Docker images
chmod +x build-and-push.sh
./build-and-push.sh

# Deploy to GKE
chmod +x deploy.sh
./deploy.sh
```

### 5. Verify Deployment (2 minutes)
```bash
# Wait for Ingress IP (may take 5-10 minutes)
kubectl get ingress microservices-ingress -w

# Once IP is assigned, test services
INGRESS_IP=$(kubectl get ingress microservices-ingress -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

curl http://$INGRESS_IP/patients
curl http://$INGRESS_IP/appointments
```

## Expected Output

### Patient Service Response
```json
{
  "message": "Patients retrieved successfully",
  "count": 2,
  "patients": [
    {"id": "1", "name": "John Doe", "age": 30, "condition": "Healthy"},
    {"id": "2", "name": "Jane Smith", "age": 45, "condition": "Hypertension"}
  ]
}
```

### Application Service Response
```json
{
  "message": "Appointments retrieved successfully",
  "count": 2,
  "appointments": [
    {"id": "1", "patientId": "1", "date": "2023-06-15", "time": "10:00", "doctor": "Dr. Smith"},
    {"id": "2", "patientId": "2", "date": "2023-06-16", "time": "14:30", "doctor": "Dr. Johnson"}
  ]
}
```

## CI/CD Automation

Once GitHub secrets are configured, the pipelines will automatically:

1. **On PR to main**:
   - Run Terraform fmt, validate, and plan
   - Show infrastructure changes

2. **On merge to main**:
   - Apply Terraform changes
   - Build Docker images
   - Push to Artifact Registry
   - Deploy to GKE

## Monitoring Setup (Optional - 5 minutes)

```bash
# Install Prometheus and Grafana
kubectl create namespace monitoring
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm install prometheus prometheus-community/kube-prometheus-stack -n monitoring

# Access Grafana
kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80

# Get password
kubectl get secret -n monitoring prometheus-grafana -o jsonpath="{.data.admin-password}" | base64 --decode
```

Open http://localhost:3000 (username: admin)

## Troubleshooting

### Issue: Terraform fails with "bucket not found"
**Solution**: Update `terraform/environments/dev/main.tf` with your bucket name

### Issue: Docker push fails
**Solution**: 
```bash
gcloud auth configure-docker us-central1-docker.pkg.dev
```

### Issue: Pods in ImagePullBackOff
**Solution**: Check if images were pushed successfully
```bash
gcloud artifacts docker images list us-central1-docker.pkg.dev/PROJECT_ID/microservices-repo
```

### Issue: Ingress not getting IP
**Solution**: Wait 5-10 minutes for GCP to provision load balancer

## Next Steps

1. **Add Health Checks**: Implement liveness and readiness probes
2. **Set up Autoscaling**: Configure HPA for automatic scaling
3. **Add Monitoring**: Set up alerts and dashboards
4. **Implement Secrets**: Use Google Secret Manager
5. **Add Tests**: Implement integration tests in CI/CD

## Cleanup

```bash
# Delete Kubernetes resources
kubectl delete -f k8s/

# Destroy infrastructure
cd terraform/environments/dev
terraform destroy -auto-approve

# Delete GCS bucket
gsutil rm -r gs://$(gcloud config get-value project)-terraform-state
```

## Cost Estimation

Approximate monthly costs (us-central1):
- GKE Cluster: ~$75/month
- 2 x e2-medium nodes: ~$50/month
- Load Balancer: ~$20/month
- Artifact Registry: ~$0.10/GB
- **Total**: ~$145-150/month

To minimize costs:
- Use preemptible nodes
- Scale down to 1 node for dev
- Delete resources when not in use

## Support

- [Deployment Guide](DEPLOYMENT_GUIDE.md) - Detailed instructions
- [Architecture](ARCHITECTURE.md) - System design
- [Monitoring](MONITORING.md) - Observability setup

For issues, check the troubleshooting section or open a GitHub issue.
