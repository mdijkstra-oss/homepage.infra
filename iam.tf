# --- upload identity ---

resource "scaleway_iam_application" "artifacts_upload" {
  name        = "artifacts-upload"
  description = "Site CI: uploads frontend build artifacts."
}

resource "scaleway_iam_policy" "artifacts_upload" {
  name           = "artifacts-upload"
  description    = "Object write, scoped to the artifacts project."
  application_id = local.artifacts_upload_app_id

  rule {
    project_ids          = [local.artifacts_project_id]
    permission_set_names = ["ObjectStorageObjectsWrite"]
  }
}

resource "scaleway_iam_api_key" "artifacts_upload" {
  application_id = local.artifacts_upload_app_id
  description    = "Woodpecker key (site repo) for artifact uploads."
  expires_at     = var.api_key_expires_at
}

# --- bucket access ---

resource "scaleway_object_bucket_policy" "site_artifacts" {
  bucket     = local.artifacts_bucket_name
  region     = var.region
  project_id = local.artifacts_project_id

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
