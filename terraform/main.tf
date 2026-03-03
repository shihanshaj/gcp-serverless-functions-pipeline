# ============================================================
# PROVIDER
# ============================================================

terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

provider "google" {
  credentials = file(var.credentials_file)
  project     = var.project_id
  region      = var.region
}

# ============================================================
# STORAGE BUCKET — Stores the function source code
# Terraform uploads your code here, GCP reads it from here
# ============================================================

resource "google_storage_bucket" "functions" {
  name                        = "${var.project_id}-functions-source"
  location                    = var.region
  force_destroy               = true
  uniform_bucket_level_access = true
}

# ============================================================
# PACKAGE + UPLOAD FUNCTION CODE
# Terraform zips each function folder and uploads to GCS
# ============================================================

# Zip the HTTP API function
data "archive_file" "http_api" {
  type        = "zip"
  source_dir  = "${path.module}/../functions/http_api"
  output_path = "${path.module}/http_api.zip"
}

# Zip the event processor function
data "archive_file" "event_processor" {
  type        = "zip"
  source_dir  = "${path.module}/../functions/event_processor"
  output_path = "${path.module}/event_processor.zip"
}

# Upload HTTP API zip to GCS
resource "google_storage_bucket_object" "http_api" {
  name   = "http_api_${data.archive_file.http_api.output_md5}.zip"
  bucket = google_storage_bucket.functions.name
  source = data.archive_file.http_api.output_path
}

# Upload event processor zip to GCS
resource "google_storage_bucket_object" "event_processor" {
  name   = "event_processor_${data.archive_file.event_processor.output_md5}.zip"
  bucket = google_storage_bucket.functions.name
  source = data.archive_file.event_processor.output_path
}

# ============================================================
# PUB/SUB TOPIC — Message queue between components
# Functions publish to this, event processor subscribes to it
# ============================================================

resource "google_pubsub_topic" "events" {
  name = "${var.app_name}-events"

  labels = {
    app = var.app_name
  }
}

# ============================================================
# CLOUD FUNCTION 1 — HTTP API
# Triggered by HTTP requests, reads/writes Firestore
# ============================================================

resource "google_cloudfunctions2_function" "http_api" {
  name        = "${var.app_name}-http-api"
  location    = var.region
  description = "HTTP API that reads and writes to Firestore"

  build_config {
    runtime     = "python311"
    entry_point = "http_api"

    source {
      storage_source {
        bucket = google_storage_bucket.functions.name
        object = google_storage_bucket_object.http_api.name
      }
    }
  }

service_config {
    max_instance_count               = 10
    min_instance_count               = 0
    available_memory                 = "512M"
    timeout_seconds                  = 120
    all_traffic_on_latest_revision   = true
    ingress_settings                 = "ALLOW_ALL"

    environment_variables = {
      PROJECT_ID = var.project_id
    }
  }
}

# Make HTTP API publicly accessible (no auth needed for demo)
resource "google_cloud_run_service_iam_member" "http_api_public" {
  location = google_cloudfunctions2_function.http_api.location
  service  = google_cloudfunctions2_function.http_api.name
  role     = "roles/run.invoker"
  member   = "allUsers"
}

# ============================================================
# CLOUD FUNCTION 2 — Event Processor
# Triggered automatically by Pub/Sub messages
# ============================================================

resource "google_cloudfunctions2_function" "event_processor" {
  name        = "${var.app_name}-event-processor"
  location    = var.region
  description = "Processes Pub/Sub events and saves to Firestore"

  build_config {
    runtime     = "python311"
    entry_point = "event_processor"

    source {
      storage_source {
        bucket = google_storage_bucket.functions.name
        object = google_storage_bucket_object.event_processor.name
      }
    }
  }

  service_config {
    max_instance_count = 10
    min_instance_count = 0
    available_memory               = "512M"
    timeout_seconds                = 120
    all_traffic_on_latest_revision = true

    environment_variables = {
      PROJECT_ID = var.project_id
    }
  }

  # This is the trigger — fires when message arrives on Pub/Sub topic
  event_trigger {
    trigger_region = var.region
    event_type     = "google.cloud.pubsub.topic.v1.messagePublished"
    pubsub_topic   = google_pubsub_topic.events.id
    retry_policy   = "RETRY_POLICY_RETRY"
  }
}

# ============================================================
# CLOUD SCHEDULER — Fires events automatically on a schedule
# Like a cron job that publishes to Pub/Sub every minute
# ============================================================

resource "google_cloud_scheduler_job" "trigger" {
  name        = "${var.app_name}-scheduler"
  description = "Publishes a metric event every minute"
  schedule    = "* * * * *" # Every minute (cron format)
  time_zone   = "UTC"
  region      = var.region

  pubsub_target {
    topic_name = google_pubsub_topic.events.id

    # Message published every minute — event processor will pick this up
    data = base64encode(jsonencode({
      type      = "metric"
      value     = 75
      source    = "scheduler"
      timestamp = "auto"
    }))
  }
}

# ============================================================
# IAM — Give Cloud Functions permission to use Firestore
# ============================================================

resource "google_project_iam_member" "functions_firestore" {
  project = var.project_id
  role    = "roles/datastore.user"
  member  = "serviceAccount:${var.project_id}@appspot.gserviceaccount.com"
}