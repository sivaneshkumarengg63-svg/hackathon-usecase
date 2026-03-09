variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "region" {
  description = "GCP Region"
  type        = string
  default     = "us-central1"
}

variable "network_name" {
  description = "VPC Network Name"
  type        = string
  default     = "gke-vpc"
}

variable "cluster_name" {
  description = "GKE Cluster Name"
  type        = string
  default     = "microservices-cluster"
}
