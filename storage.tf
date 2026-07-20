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
  project_id = local.artifacts_project_id

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
