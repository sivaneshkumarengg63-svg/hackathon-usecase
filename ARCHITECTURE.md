# Architecture Diagram

## High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                         GitHub Repository                        │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐          │
│  │   Patient    │  │ Application  │  │    Order     │          │
│  │   Service    │  │   Service    │  │   Service    │          │
│  └──────────────┘  └──────────────┘  └──────────────┘          │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                      GitHub Actions CI/CD                        │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐          │
│  │  Terraform   │  │Docker Build  │  │ GKE Deploy   │          │
│  │   Workflow   │  │  & Push      │  │   Workflow   │          │
│  └──────────────┘  └──────────────┘  └──────────────┘          │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                    Google Cloud Platform                         │
│                                                                   │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │              Artifact Registry (GCR)                       │ │
│  │  ┌──────────┐  ┌──────────┐  ┌──────────┐                │ │
│  │  │ Patient  │  │   App    │  │  Order   │                │ │
│  │  │  Image   │  │  Image   │  │  Image   │                │ │
│  │  └──────────┘  └──────────┘  └──────────┘                │ │
│  └────────────────────────────────────────────────────────────┘ │
│                              │                                    │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │                    VPC Network                             │ │
│  │  ┌──────────────────┐      ┌──────────────────┐           │ │
│  │  │ Public Subnet    │      │ Private Subnet   │           │ │
│  │  │ 10.0.1.0/24      │      │ 10.0.2.0/24      │           │ │
│  │  └──────────────────┘      └──────────────────┘           │ │
│  │           │                          │                      │ │
│  │           │    ┌─────────────────────┴──────────┐          │ │
│  │           │    │   GKE Cluster                  │          │ │
│  │           │    │  ┌──────────────────────────┐  │          │ │
│  │           │    │  │    Node Pool (2 nodes)   │  │          │ │
│  │           │    │  │    e2-medium             │  │          │ │
│  │           │    │  └──────────────────────────┘  │          │ │
│  │           │    │                                 │          │ │
│  │           │    │  ┌────────────────────────┐    │          │ │
│  │           │    │  │  Patient Service       │    │          │
│  │           │    │  │  (2 replicas)          │    │          │
│  │           │    │  └────────────────────────┘    │          │ │
│  │           │    │                                 │          │ │
│  │           │    │  ┌────────────────────────┐    │          │ │
│  │           │    │  │  Application Service   │    │          │
│  │           │    │  │  (2 replicas)          │    │          │
│  │           │    │  └────────────────────────┘    │          │ │
│  │           │    │                                 │          │ │
│  │           │    │  ┌────────────────────────┐    │          │ │
│  │           │    │  │  Order Service         │    │          │
│  │           │    │  │  (2 replicas)          │    │          │
│  │           │    │  └────────────────────────┘    │          │ │
│  │           │    └─────────────────────────────────┘          │ │
│  │           │                                                  │ │
│  │  ┌────────▼──────────┐                                      │ │
│  │  │  Load Balancer    │                                      │ │
│  │  │  (Ingress)        │                                      │ │
│  │  └───────────────────┘                                      │ │
│  └────────────────────────────────────────────────────────────┘ │
│                                                                   │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │              Monitoring & Logging                          │ │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐    │ │
│  │  │Cloud Logging │  │Cloud Monitor │  │  Prometheus  │    │ │
│  │  └──────────────┘  └──────────────┘  └──────────────┘    │ │
│  └────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
                        ┌──────────┐
                        │  Users   │
                        └──────────┘
```

## Component Details

### Infrastructure Layer (Terraform)
- **VPC**: Custom network with public and private subnets
- **GKE Cluster**: Managed Kubernetes cluster with 2 nodes
- **Artifact Registry**: Docker image repository
- **IAM**: Service accounts and role bindings
- **Cloud NAT**: Outbound internet access for private subnet

### Application Layer (Kubernetes)
- **Patient Service**: Node.js REST API (Port 3000)
- **Application Service**: Node.js REST API (Port 3001)
- **Order Service**: Java Spring Boot REST API (Port 8080)
- **Ingress**: GCE Load Balancer for external access

### CI/CD Pipeline
1. **Code Push** → GitHub Repository
2. **Terraform Workflow** → Infrastructure provisioning
3. **Docker Build** → Build and push images to Artifact Registry
4. **GKE Deploy** → Deploy to Kubernetes cluster

### Monitoring & Logging
- **Cloud Logging**: Centralized log aggregation
- **Cloud Monitoring**: Metrics and alerting
- **Prometheus** (Optional): Custom metrics collection
- **Grafana** (Optional): Visualization dashboards

## Network Flow

```
Internet → Load Balancer → Ingress → Services → Pods
                                    ↓
                            Cloud Logging
                            Cloud Monitoring
```

## Security Features

1. **Private GKE Nodes**: Nodes in private subnet
2. **Workload Identity**: Secure pod-to-GCP authentication
3. **IAM Roles**: Least privilege access
4. **Network Policies**: Pod-to-pod communication control
5. **Artifact Registry**: Private container registry

## Scalability

- **Horizontal Pod Autoscaling**: Automatic pod scaling based on CPU/memory
- **Cluster Autoscaling**: Automatic node scaling
- **Load Balancing**: Distributed traffic across replicas
- **Multi-zone Deployment**: High availability across zones
