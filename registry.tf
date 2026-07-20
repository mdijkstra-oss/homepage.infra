resource "scaleway_registry_namespace" "main" {
  name        = "mdijkstra-homepage"
  description = "Container images for the homepage stack."
  is_public   = false
  region      = var.region
  project_id  = local.main_project_id
}
