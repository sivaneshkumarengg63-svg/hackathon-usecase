# GKE Microservices Deployment Guide

## Architecture Overview

This project deploys three microservices to Google Kubernetes Engine (GKE):
- **Patient Service** (Node.js) - Port 3000
- **Application Service** (Node.js) - Port 3001  
- **Order Service** (Java Spring Boot) - Port 8080

## Prerequisites

1. **GCP Account** with billing enabled
2. **gcloud CLI** installed and configured
3. **Terraform** >= 1.6.0
4. **kubectl** installed
5. **Docker** installed
6. **GitHub** account

## Setup Instructions

### Step 1: GCP Project Setup

```bash
# Set your project ID
export PROJECT_ID="your-gcp-project-id"
export REGION="us-central1"

# Set the project
gcloud config set project $PROJECT_ID

# Enable required APIs
gcloud services enable container.googleapis.com
gcloud services enable compute.googleapis.com
gcloud services enable artifactregistry.googleapis.com
gcloud services enable cloudresourcemanager.googleapis.com
```

### Step 2: Create GCS Bucket for Terraform State

```bash
# Create bucket for Terraform state
gsutil mb -p $PROJECT_ID -l $REGION gs://${PROJECT_ID}-terraform-state

# Enable versioning
gsutil versioning set on gs://${PROJECT_ID}-terraform-state
```

### Step 3: Create Service Account for GitHub Actions

```bash
# Create service account
gcloud iam service-accounts create github-actions \
    --display-name="GitHub Actions Service Account"

# Grant necessary roles
gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:github-actions@${PROJECT_ID}.iam.gserviceaccount.com" \
    --role="roles/container.admin"

gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:github-actions@${PROJECT_ID}.iam.gserviceaccount.com" \
    --role="roles/artifactregistry.admin"

gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:github-actions@${PROJECT_ID}.iam.gserviceaccount.com" \
    --role="roles/compute.admin"

# Create and download key
gcloud iam service-accounts keys create github-actions-key.json \
    --iam-account=github-actions@${PROJECT_ID}.iam.gserviceaccount.com
```

### Step 4: Configure Terraform

```bash
cd terraform/environments/dev

# Copy and edit terraform.tfvars
cp terraform.tfvars.example terraform.tfvars

# Edit terraform.tfvars with your values
# project_id   = "your-gcp-project-id"
# region       = "us-central1"

# Update backend configuration in main.tf
# Replace YOUR_BUCKET_NAME with: ${PROJECT_ID}-terraform-state
```

### Step 5: Deploy Infrastructure with Terraform

```bash
# Initialize Terraform
terraform init

# Validate configuration
terraform validate

# Plan deployment
terraform plan

# Apply configuration
terraform apply
```

### Step 6: Configure GitHub Secrets

Add the following secrets to your GitHub repository (Settings > Secrets and variables > Actions):

- `GCP_PROJECT_ID`: Your GCP project ID
- `GCP_SA_KEY`: Contents of github-actions-key.json file

### Step 7: Local Docker Build and Push (Optional)

```bash
# Authenticate Docker with Artifact Registry
gcloud auth configure-docker ${REGION}-docker.pkg.dev

# Build and push images
docker build -t ${REGION}-docker.pkg.dev/${PROJECT_ID}/microservices-repo/patient-service:latest ./patient-service
docker push ${REGION}-docker.pkg.dev/${PROJECT_ID}/microservices-repo/patient-service:latest

docker build -t ${REGION}-docker.pkg.dev/${PROJECT_ID}/microservices-repo/application-service:latest ./application-service
docker push ${REGION}-docker.pkg.dev/${PROJECT_ID}/microservices-repo/application-service:latest

docker build -t ${REGION}-docker.pkg.dev/${PROJECT_ID}/microservices-repo/order-service:latest ./order-service
docker push ${REGION}-docker.pkg.dev/${PROJECT_ID}/microservices-repo/order-service:latest
```

### Step 8: Deploy to GKE

```bash
# Get cluster credentials
gcloud container clusters get-credentials microservices-cluster \
    --region $REGION \
    --project $PROJECT_ID

# Update K8s manifests with your project details
sed -i "s|REGION|${REGION}|g" k8s/*.yaml
sed -i "s|PROJECT_ID|${PROJECT_ID}|g" k8s/*.yaml

# Deploy services
kubectl apply -f k8s/patient-service.yaml
kubectl apply -f k8s/application-service.yaml
kubectl apply -f k8s/order-service.yaml
kubectl apply -f k8s/ingress.yaml

# Check deployment status
kubectl get deployments
kubectl get services
kubectl get ingress
```

## CI/CD Pipeline

The project includes three GitHub Actions workflows:

### 1. Terraform CI/CD (`terraform.yml`)
- **On PR**: Runs fmt, validate, and plan
- **On merge to main**: Runs apply

### 2. Docker Build (`docker-build.yml`)
- Builds and pushes Docker images to Artifact Registry
- Triggers on changes to service directories

### 3. GKE Deployment (`deploy-gke.yml`)
- Deploys services to GKE
- Triggers after successful Docker build

## Monitoring and Logging

### View Logs
```bash
# View logs for a service
kubectl logs -l app=patient-service --tail=100

# Stream logs
kubectl logs -f deployment/patient-service
```

### Access GCP Monitoring
1. Go to GCP Console > Kubernetes Engine > Workloads
2. Click on any deployment to view metrics
3. Navigate to Cloud Logging for detailed logs

### Prometheus & Grafana (Bonus)
```bash
# Install Prometheus
kubectl create namespace monitoring
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm install prometheus prometheus-community/kube-prometheus-stack -n monitoring

# Access Grafana
kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80
# Default credentials: admin/prom-operator
```

## Testing the Deployment

```bash
# Get Ingress IP
INGRESS_IP=$(kubectl get ingress microservices-ingress -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

# Test Patient Service
curl http://$INGRESS_IP/patients

# Test Application Service
curl http://$INGRESS_IP/appointments

# Test Order Service
curl http://$INGRESS_IP/orders
```

## Cleanup

```bash
# Delete Kubernetes resources
kubectl delete -f k8s/

# Destroy Terraform infrastructure
cd terraform/environments/dev
terraform destroy

# Delete GCS bucket
gsutil rm -r gs://${PROJECT_ID}-terraform-state
```

## Troubleshooting

### Pods not starting
```bash
kubectl describe pod <pod-name>
kubectl logs <pod-name>
```

### Ingress not getting IP
```bash
kubectl describe ingress microservices-ingress
# Wait 5-10 minutes for GCP to provision load balancer
```

### Image pull errors
```bash
# Verify Artifact Registry permissions
gcloud artifacts repositories describe microservices-repo --location=$REGION
```

## Project Structure

```
.
├── .github/
│   └── workflows/
│       ├── terraform.yml
│       ├── docker-build.yml
│       └── deploy-gke.yml
├── terraform/
│   ├── modules/
│   │   ├── vpc/
│   │   ├── gke/
│   │   └── iam/
│   └── environments/
│       └── dev/
├── k8s/
│   ├── patient-service.yaml
│   ├── application-service.yaml
│   ├── order-service.yaml
│   └── ingress.yaml
├── patient-service/
│   ├── Dockerfile
│   └── src/
├── application-service/
│   ├── Dockerfile
│   └── src/
└── order-service/
    ├── Dockerfile
    ├── pom.xml
    └── src/
```
