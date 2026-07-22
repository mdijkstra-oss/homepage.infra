locals {
  name_prefix     = "${var.project}-${var.env}"
  main_project_id = var.project_id

  artifacts_bucket_name   = scaleway_object_bucket.site_artifacts.name
  artifacts_upload_app_id = scaleway_iam_application.artifacts_upload.id

  # Hand-created backend bucket (see versions.tf); named here so it can be fenced.
  tfstate_bucket_name = "mdijkstra-homepage-tfstate"

  # Every bucket in this project EXCEPT the artifacts bucket itself. The
  # artifacts-upload CI identity holds project-wide object-write — Scaleway IAM
  # cannot scope a permission set to a single bucket (see README) — so each of
  # these needs an explicit fence policy denying that identity.
  # ADD EVERY NEW NON-ARTIFACTS BUCKET HERE, or the CI key can write to it.
  fenced_buckets = toset([
    scaleway_object_bucket.site.name,
    local.tfstate_bucket_name,
  ])
}
