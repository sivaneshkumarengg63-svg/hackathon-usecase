#!/bin/bash

# Deploy to GKE

set -e

PROJECT_ID=$(gcloud config get-value project)
REGION="us-central1"
CLUSTER_NAME="microservices-cluster"

echo "=== Deploying to GKE ==="
echo ""

# Get cluster credentials
echo "Getting cluster credentials..."
gcloud container clusters get-credentials ${CLUSTER_NAME} \
    --region ${REGION} \
    --project ${PROJECT_ID}

# Update manifests with project details
echo "Updating Kubernetes manifests..."
for file in k8s/*.yaml; do
    sed -i.bak "s|REGION|${REGION}|g" "$file"
    sed -i.bak "s|PROJECT_ID|${PROJECT_ID}|g" "$file"
    rm "${file}.bak"
done

# Deploy services
echo "Deploying services..."
kubectl apply -f k8s/patient-service.yaml
kubectl apply -f k8s/application-service.yaml
kubectl apply -f k8s/order-service.yaml
kubectl apply -f k8s/ingress.yaml

# Wait for deployments
echo ""
echo "Waiting for deployments to be ready..."
kubectl rollout status deployment/patient-service
kubectl rollout status deployment/application-service
kubectl rollout status deployment/order-service

# Display status
echo ""
echo "=== Deployment Status ==="
kubectl get deployments
echo ""
kubectl get services
echo ""
kubectl get ingress

echo ""
echo "=== Deployment Complete ==="
echo ""
echo "To get the Ingress IP address:"
echo "  kubectl get ingress microservices-ingress"
echo ""
echo "To test the services:"
echo "  INGRESS_IP=\$(kubectl get ingress microservices-ingress -o jsonpath='{.status.loadBalancer.ingress[0].ip}')"
echo "  curl http://\$INGRESS_IP/patients"
echo "  curl http://\$INGRESS_IP/appointments"
