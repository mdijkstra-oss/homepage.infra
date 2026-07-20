locals {
  name_prefix          = "${var.project}-${var.env}"
  main_project_id      = var.project_id
  artifacts_project_id = scaleway_account_project.artifacts.id

  artifacts_bucket_name   = scaleway_object_bucket.site_artifacts.name
  artifacts_upload_app_id = scaleway_iam_application.artifacts_upload.id
}
