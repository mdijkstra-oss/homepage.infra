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

# --- inference identity ---
#
# The backend container's credential for Generative APIs. Scaleway authenticates
# that endpoint with an IAM secret key rather than a key issued by the model
# vendor, so it is created here and read straight onto the container. Nothing is
# copied by hand and no value has to exist outside this configuration.

resource "scaleway_iam_application" "inference" {
  name        = "inference"
  description = "Backend: calls Generative APIs."
}

resource "scaleway_iam_policy" "inference" {
  name           = "inference"
  description    = "Generative APIs model access."
  application_id = local.inference_app_id

  rule {
    project_ids = [local.main_project_id]
    # Enough to call a model and list the catalogue, and not enough to create or
    # delete a dedicated deployment. Supersedes the older InferenceReadOnly.
    permission_set_names = ["GenerativeApisModelAccess"]
  }
}

resource "scaleway_iam_api_key" "inference" {
  application_id     = local.inference_app_id
  description        = "Backend container credential for Generative APIs."
  expires_at         = var.api_key_expires_at
  default_project_id = local.main_project_id
}
