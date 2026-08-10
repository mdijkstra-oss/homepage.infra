output "registry_endpoint" {
  value       = scaleway_registry_namespace.main.endpoint
  description = "Registry push/pull endpoint."
}

output "site_url" {
  value       = one(scaleway_container.site[*].public_endpoint)
  description = "Generated endpoint the site container answers on, which keeps working alongside the custom domain. Null until site_release is set."
}

output "backend_url" {
  value       = one(scaleway_container.backend[*].public_endpoint)
  description = "Generated endpoint the backend container answers on. Null until backend_release is set."
}

output "site_origin" {
  value       = local.site_origin
  description = "What the backend allows as CORS_ORIGINS and what a browser sends as Origin."
}

output "agent_url" {
  value       = var.domain == "" ? null : "https://agent.${var.domain}/cv"
  description = "The site repo's VITE_AGENT_URL. Determined by the domain alone, so it can be set before the backend answers on it. Null until domain is set."
}

output "registry_push_access_key" {
  value       = scaleway_iam_api_key.registry_push.access_key
  description = "Access key for the registry-push identity, held as a GitHub Actions secret in the site and backend repos."
}

output "registry_push_secret_key" {
  value       = scaleway_iam_api_key.registry_push.secret_key
  description = "Secret key for the registry-push identity, held as a GitHub Actions secret in the site and backend repos."
  sensitive   = true
}
