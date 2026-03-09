#!/bin/bash

# Build and Push Docker Images to Artifact Registry

set -e

# Configuration
PROJECT_ID=$(gcloud config get-value project)
REGION="us-central1"
REGISTRY="${REGION}-docker.pkg.dev"
REPO_NAME="microservices-repo"

echo "=== Building and Pushing Docker Images ==="
echo "Project: $PROJECT_ID"
echo "Registry: $REGISTRY"
echo ""

# Authenticate Docker
echo "Authenticating Docker with Artifact Registry..."
gcloud auth configure-docker ${REGISTRY}

# Services to build
SERVICES=("patient-service" "application-service" "order-service")

for SERVICE in "${SERVICES[@]}"; do
    echo ""
    echo "Building $SERVICE..."
    
    IMAGE_NAME="${REGISTRY}/${PROJECT_ID}/${REPO_NAME}/${SERVICE}"
    
    docker build -t ${IMAGE_NAME}:latest \
                 -t ${IMAGE_NAME}:$(git rev-parse --short HEAD) \
                 ./${SERVICE}
    
    echo "Pushing $SERVICE..."
    docker push ${IMAGE_NAME}:latest
    docker push ${IMAGE_NAME}:$(git rev-parse --short HEAD)
    
    echo "✓ $SERVICE completed"
done

echo ""
echo "=== All images built and pushed successfully ==="
echo ""
echo "Images available at:"
for SERVICE in "${SERVICES[@]}"; do
    echo "  ${REGISTRY}/${PROJECT_ID}/${REPO_NAME}/${SERVICE}:latest"
done
