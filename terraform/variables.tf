variable "project_id" {
  description = "Your GCP project ID"
  default     = "cloud-portfolio-489014"
}

variable "region" {
  description = "GCP region"
  default     = "us-central1"
}

variable "app_name" {
  description = "Name prefix for all resources"
  default     = "serverless-pipeline"
}

variable "credentials_file" {
  description = "Path to GCP service account credentials JSON"
  default     = "/Users/shihanshaj/Desktop/gcp-credentials.json"
}