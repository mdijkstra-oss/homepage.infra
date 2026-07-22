# Everything lives in one project. That means the artifacts-upload CI identity —
# which has project-wide object-write — can reach every bucket here unless it is
# explicitly fenced. When you add a bucket, also add it to `fenced_buckets` in
# locals.tf (unless it is meant to be CI-writable). See README for the why.

resource "scaleway_object_bucket" "site" {
  name       = "mdijkstra-homepage-site"
  region     = var.region
  project_id = local.main_project_id

  tags = {
    project = var.project
    env     = var.env
  }
}

resource "scaleway_object_bucket" "site_artifacts" {
  name       = "mdijkstra-homepage-site-artifacts"
  region     = var.region
  project_id = local.main_project_id

  # Artifacts are reproducible (re-tag to rebuild) and expire in 90 days, so a
  # non-empty bucket should not block replacement/teardown.
  force_destroy = true

  tags = {
    project = var.project
    env     = var.env
    role    = "artifacts"
  }

  lifecycle_rule {
    id      = "expire-old-releases"
    prefix  = "releases/"
    enabled = true

    expiration {
      days = 90
    }
  }
}
