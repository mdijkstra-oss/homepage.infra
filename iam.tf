# --- registry push identity ---
#
# CI credential for the two application repos, which build their container image
# and push it to the registry namespace on tag. Its key is a GitHub Actions
# secret in both of them.

resource "scaleway_iam_application" "registry_push" {
  name        = "registry-push"
  description = "Site and backend CI: pushes container images to the registry."
}

resource "scaleway_iam_policy" "registry_push" {
  name = "registry-push"
  # Scaleway IAM cannot scope Container Registry below the project — there is no
  # per-namespace grant (open upstream feature request). So this grants push and
  # delete across every registry namespace in the project. One namespace exists
  # today; see README for the accepted blast radius and the tightening path.
  description    = "Container Registry push across the project."
  application_id = local.registry_push_app_id

  rule {
    project_ids          = [local.main_project_id]
    permission_set_names = ["ContainerRegistryFullAccess"]
  }
}

resource "scaleway_iam_api_key" "registry_push" {
  application_id     = local.registry_push_app_id
  description        = "GitHub Actions secret (site and backend repos) for registry pushes."
  expires_at         = var.api_key_expires_at
  default_project_id = local.main_project_id
}
