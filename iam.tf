# --- upload identity ---

resource "scaleway_iam_application" "artifacts_upload" {
  name        = "artifacts-upload"
  description = "Site CI: uploads frontend build artifacts."
}

resource "scaleway_iam_policy" "artifacts_upload" {
  name = "artifacts-upload"
  # Scaleway IAM cannot scope object storage to a single bucket — the finest
  # grain is the project. So this grants object-write across the whole project;
  # the fence policies below keep it out of every bucket but the artifacts one.
  description    = "Object write across the project; narrowed by bucket policies."
  application_id = local.artifacts_upload_app_id

  rule {
    project_ids          = [local.main_project_id]
    permission_set_names = ["ObjectStorageObjectsWrite"]
  }
}

resource "scaleway_iam_api_key" "artifacts_upload" {
  application_id = local.artifacts_upload_app_id
  description    = "Woodpecker key (site repo) for artifact uploads."
  expires_at     = var.api_key_expires_at

  # Scaleway scopes every S3 request to the key's default project; all buckets
  # now live in the main project, so the key must default to it.
  default_project_id = local.main_project_id
}

# --- registry push identity ---
#
# CI credential for the site-prompts repo, which builds a config image and
# pushes it to the registry namespace on tag. Its key lives in Woodpecker as
# `scw_secret_key`.

resource "scaleway_iam_application" "registry_push" {
  name        = "registry-push"
  description = "site-prompts CI: pushes container images to the registry."
}

resource "scaleway_iam_policy" "registry_push" {
  name = "registry-push"
  # Scaleway IAM cannot scope Container Registry below the project — there is no
  # per-namespace grant (open upstream feature request), and no bucket-policy
  # equivalent to fence it like the object-storage identity above. So this grants
  # push (and delete) across every registry namespace in the project. One
  # namespace exists today; see README for the accepted blast radius and the
  # tightening path.
  description    = "Container Registry push across the project."
  application_id = local.registry_push_app_id

  rule {
    project_ids          = [local.main_project_id]
    permission_set_names = ["ContainerRegistryFullAccess"]
  }
}

resource "scaleway_iam_api_key" "registry_push" {
  application_id     = local.registry_push_app_id
  description        = "Woodpecker key (site-prompts repo) for registry pushes."
  expires_at         = var.api_key_expires_at
  default_project_id = local.main_project_id
}

# --- bucket access ---

resource "scaleway_object_bucket_policy" "site_artifacts" {
  bucket     = local.artifacts_bucket_name
  region     = var.region
  project_id = local.main_project_id

  policy = jsonencode({
    Version = "2023-04-17"
    Statement = [
      # Scaleway recommends naming the owner explicitly — policies are deny-by-default.
      {
        Sid       = "OwnerFullAccess"
        Effect    = "Allow"
        Principal = { SCW = "user_id:${var.owner_user_id}" }
        Action    = ["s3:*"]
        Resource = [
          local.artifacts_bucket_name,
          "${local.artifacts_bucket_name}/*",
        ]
      },
      {
        Sid       = "ArtifactsUploadPutReleasesOnly"
        Effect    = "Allow"
        Principal = { SCW = "application_id:${local.artifacts_upload_app_id}" }
        Action    = ["s3:PutObject"]
        Resource  = ["${local.artifacts_bucket_name}/releases/*"]
      },
    ]
  })
}

# --- fences: keep the CI identity out of every other bucket in the project ---
#
# The IAM grant is project-wide, so each non-artifacts bucket carries a policy
# that (a) keeps the owner in — bucket policies are deny-by-default, so this is
# what stops Tofu locking itself out of the state bucket — and (b) explicitly
# denies the artifacts-upload application. Buckets come from `fenced_buckets` in
# locals.tf; add new ones there.
resource "scaleway_object_bucket_policy" "fence_artifacts_upload" {
  for_each = local.fenced_buckets

  bucket     = each.value
  region     = var.region
  project_id = local.main_project_id

  policy = jsonencode({
    Version = "2023-04-17"
    Statement = [
      {
        Sid       = "OwnerFullAccess"
        Effect    = "Allow"
        Principal = { SCW = "user_id:${var.owner_user_id}" }
        Action    = ["s3:*"]
        Resource  = [each.value, "${each.value}/*"]
      },
      {
        Sid       = "DenyArtifactsUploadApp"
        Effect    = "Deny"
        Principal = { SCW = "application_id:${local.artifacts_upload_app_id}" }
        Action    = ["s3:*"]
        Resource  = [each.value, "${each.value}/*"]
      },
    ]
  })
}
