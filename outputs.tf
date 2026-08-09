output "registry_endpoint" {
  value       = scaleway_registry_namespace.main.endpoint
  description = "Registry push/pull endpoint."
}

output "site_bucket_endpoint" {
  value       = scaleway_object_bucket.site.endpoint
  description = "Live static site bucket endpoint."
}

output "site_artifacts_bucket" {
  value       = scaleway_object_bucket.site_artifacts.name
  description = "Bucket for versioned frontend build artifacts."
}

output "artifacts_upload_access_key" {
  value       = scaleway_iam_api_key.artifacts_upload.access_key
  description = "Access key for the artifacts-upload identity."
}

output "artifacts_upload_secret_key" {
  value       = scaleway_iam_api_key.artifacts_upload.secret_key
  description = "Secret key for the artifacts-upload identity."
  sensitive   = true
}

output "registry_push_access_key" {
  value       = scaleway_iam_api_key.registry_push.access_key
  description = "Access key for the registry-push identity."
}

output "registry_push_secret_key" {
  value       = scaleway_iam_api_key.registry_push.secret_key
  description = "Secret key for the registry-push identity (Woodpecker secret scw_secret_key)."
  sensitive   = true
}
