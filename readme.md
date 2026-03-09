# Healthcare Microservices on GKE

A complete end-to-end solution for deploying containerized microservices to Google Kubernetes Engine (GKE) with Infrastructure as Code, CI/CD pipelines, and monitoring.

## 🏗️ Architecture

This project demonstrates a production-ready microservices architecture on GCP:

- **3 Microservices**: Patient Service, Application Service, Order Service
- **Infrastructure as Code**: Terraform modules for VPC, GKE, IAM
- **Container Registry**: Google Artifact Registry
- **Orchestration**: Kubernetes on GKE
- **CI/CD**: GitHub Actions workflows
- **Monitoring**: Cloud Logging, Cloud Monitoring, Prometheus (optional)

## 📋 Services

### Patient Service (Node.js)
- Port: 3000
- Endpoints: `/health`, `/patients`, `/patients/:id`
- Manages patient records

### Application Service (Node.js)
- Port: 3001
- Endpoints: `/health`, `/appointments`, `/appointments/:id`
- Manages appointment scheduling

### Order Service (Java Spring Boot)
- Port: 8080
- Endpoints: `/actuator/health`, `/orders`
- Manages order processing

## 🚀 Quick Start

### Prerequisites
- GCP account with billing enabled
- gcloud CLI installed
- Terraform >= 1.6.0
- kubectl installed
- Docker installed

### 1. Clone and Setup

```bash
git clone <your-repo>
cd hackathon-usecase

# Run setup script (Linux/Mac)
chmod +x setup.sh
./setup.sh
```

### 2. Deploy Infrastructure

```bash
cd terraform/environments/dev
terraform init
terraform plan
terraform apply
```

### 3. Build and Deploy

```bash
# Get cluster credentials
gcloud container clusters get-credentials microservices-cluster \
    --region us-central1 \
    --project YOUR_PROJECT_ID

# Build and push images
./build-and-push.sh

# Deploy to GKE
kubectl apply -f k8s/
```

## 📁 Project Structure

```
.
├── .github/workflows/       # CI/CD pipelines
│   ├── terraform.yml        # Terraform automation
│   ├── docker-build.yml     # Docker image builds
│   └── deploy-gke.yml       # GKE deployment
├── terraform/               # Infrastructure as Code
│   ├── modules/             # Reusable Terraform modules
│   │   ├── vpc/            # VPC networking
│   │   ├── gke/            # GKE cluster
│   │   └── iam/            # IAM roles
│   └── environments/
│       └── dev/            # Dev environment config
├── k8s/                    # Kubernetes manifests
│   ├── patient-service.yaml
│   ├── application-service.yaml
│   ├── order-service.yaml
│   └── ingress.yaml
├── patient-service/        # Patient microservice
├── application-service/    # Appointment microservice
├── order-service/          # Order microservice
├── DEPLOYMENT_GUIDE.md     # Detailed deployment guide
└── ARCHITECTURE.md         # Architecture documentation
```

## 🔄 CI/CD Pipeline

### Terraform Workflow
- **On PR**: Format check, validate, plan
- **On merge**: Apply changes automatically

### Docker Build Workflow
- Builds all three services
- Pushes to Artifact Registry
- Tags with commit SHA and latest

### GKE Deploy Workflow
- Deploys to GKE cluster
- Verifies deployment status
- Updates running services

## 📊 Monitoring

### Cloud Logging
```bash
# View logs
gcloud logging read "resource.type=k8s_container" --limit 50
```

### Cloud Monitoring
- Navigate to GCP Console > Kubernetes Engine > Workloads
- View metrics, CPU, memory usage

### Prometheus & Grafana (Optional)
```bash
# Install monitoring stack
kubectl create namespace monitoring
helm install prometheus prometheus-community/kube-prometheus-stack -n monitoring

# Access Grafana
kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80
```

## 🧪 Testing

```bash
# Get Ingress IP
INGRESS_IP=$(kubectl get ingress microservices-ingress -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

# Test endpoints
curl http://$INGRESS_IP/patients
curl http://$INGRESS_IP/appointments
curl http://$INGRESS_IP/orders
```

## 🔐 Security

- Private GKE nodes in private subnet
- Workload Identity for pod authentication
- IAM roles with least privilege
- Secrets stored in Google Secret Manager
- Network policies for pod isolation

## 📚 Documentation

- [Deployment Guide](DEPLOYMENT_GUIDE.md) - Step-by-step deployment instructions
- [Architecture](ARCHITECTURE.md) - Detailed architecture diagrams and explanations

## 🛠️ Troubleshooting

### Pods not starting
```bash
kubectl describe pod <pod-name>
kubectl logs <pod-name>
```

### Ingress not getting IP
Wait 5-10 minutes for GCP to provision the load balancer

### Image pull errors
```bash
gcloud artifacts repositories describe microservices-repo --location=us-central1
```

## 🧹 Cleanup

```bash
# Delete Kubernetes resources
kubectl delete -f k8s/

# Destroy infrastructure
cd terraform/environments/dev
terraform destroy
```

## 📝 License

This project is for educational purposes as part of the DevOps Hackathon Challenge.

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Commit your changes
4. Push to the branch
5. Create a Pull Request

## 📧 Support

For issues and questions, please open an issue in the GitHub repository.
