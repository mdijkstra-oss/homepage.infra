resource "scaleway_account_project" "artifacts" {
  name            = "homepage-artifacts"
  organization_id = var.organization_id
  description     = "Isolated project for versioned frontend build artifacts."
}
