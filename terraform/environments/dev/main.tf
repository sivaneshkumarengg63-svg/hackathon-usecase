terraform {
  required_version = ">= 1.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
  backend "gcs" {
    bucket = "YOUR_BUCKET_NAME"  # Replace with your GCS bucket
    prefix = "terraform/dev"
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

module "vpc" {
  source       = "../../modules/vpc"
  project_id   = var.project_id
  region       = var.region
  network_name = var.network_name
}

module "iam" {
  source     = "../../modules/iam"
  project_id = var.project_id
}

module "gke" {
  source       = "../../modules/gke"
  project_id   = var.project_id
  region       = var.region
  cluster_name = var.cluster_name
  network_name = module.vpc.network_name
  subnet_name  = module.vpc.private_subnet_name

  depends_on = [module.vpc]
}

resource "google_artifact_registry_repository" "repo" {
  location      = var.region
  repository_id = "microservices-repo"
  format        = "DOCKER"
  project       = var.project_id
}
