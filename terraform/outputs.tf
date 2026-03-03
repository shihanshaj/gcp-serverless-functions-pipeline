output "http_api_url" {
  description = "Your HTTP API URL — use this to test the function"
  value       = google_cloudfunctions2_function.http_api.service_config[0].uri
}

output "event_processor_name" {
  value = google_cloudfunctions2_function.event_processor.name
}

output "pubsub_topic" {
  value = google_pubsub_topic.events.name
}

output "scheduler_name" {
  value = google_cloud_scheduler_job.trigger.name
}

output "firestore_console" {
  description = "View your data here"
  value       = "https://console.cloud.google.com/firestore/databases/-default-/data/panel?project=${var.project_id}"
}