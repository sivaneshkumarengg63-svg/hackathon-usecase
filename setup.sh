#!/bin/bash

# GCP Setup Script for GKE Microservices Deployment

set -e

echo "=== GCP GKE Microservices Setup ==="
echo ""

# Check if gcloud is installed
if ! command -v gcloud &> /dev/null; then
    echo "Error: gcloud CLI is not installed"
    exit 1
fi

# Prompt for project ID
read -p "Enter your GCP Project ID: " PROJECT_ID
read -p "Enter your preferred region (default: us-central1): " REGION
REGION=${REGION:-us-central1}

echo ""
echo "Setting up project: $PROJECT_ID in region: $REGION"
echo ""

# Set project
gcloud config set project $PROJECT_ID

# Enable required APIs
echo "Enabling required GCP APIs..."
gcloud services enable container.googleapis.com
gcloud services enable compute.googleapis.com
gcloud services enable artifactregistry.googleapis.com
gcloud services enable cloudresourcemanager.googleapis.com
gcloud services enable servicenetworking.googleapis.com

# Create GCS bucket for Terraform state
echo "Creating GCS bucket for Terraform state..."
BUCKET_NAME="${PROJECT_ID}-terraform-state"
gsutil mb -p $PROJECT_ID -l $REGION gs://$BUCKET_NAME 2>/dev/null || echo "Bucket already exists"
gsutil versioning set on gs://$BUCKET_NAME

# Create service account for GitHub Actions
echo "Creating service account for GitHub Actions..."
SA_NAME="github-actions"
SA_EMAIL="${SA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"

gcloud iam service-accounts create $SA_NAME \
    --display-name="GitHub Actions Service Account" 2>/dev/null || echo "Service account already exists"

# Grant roles
echo "Granting IAM roles..."
gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:${SA_EMAIL}" \
    --role="roles/container.admin" --quiet

gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:${SA_EMAIL}" \
    --role="roles/artifactregistry.admin" --quiet

gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:${SA_EMAIL}" \
    --role="roles/compute.admin" --quiet

gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:${SA_EMAIL}" \
    --role="roles/iam.serviceAccountUser" --quiet

# Create service account key
echo "Creating service account key..."
gcloud iam service-accounts keys create github-actions-key.json \
    --iam-account=$SA_EMAIL

# Update terraform.tfvars
echo "Updating Terraform configuration..."
cat > terraform/environments/dev/terraform.tfvars <<EOF
project_id   = "$PROJECT_ID"
region       = "$REGION"
network_name = "gke-vpc"
cluster_name = "microservices-cluster"
EOF

# Update backend configuration
sed -i "s/YOUR_BUCKET_NAME/$BUCKET_NAME/g" terraform/environments/dev/main.tf

echo ""
echo "=== Setup Complete ==="
echo ""
echo "Next steps:"
echo "1. Add the following secrets to your GitHub repository:"
echo "   - GCP_PROJECT_ID: $PROJECT_ID"
echo "   - GCP_SA_KEY: (contents of github-actions-key.json)"
echo ""
echo "2. Deploy infrastructure:"
echo "   cd terraform/environments/dev"
echo "   terraform init"
echo "   terraform plan"
echo "   terraform apply"
echo ""
echo "3. Push code to GitHub to trigger CI/CD pipelines"
echo ""
echo "Service account key saved to: github-actions-key.json"
echo "Keep this file secure and do not commit it to version control!"
