provider "scaleway" {}

# An empty token is what keeps this repository able to plan without a Better
# Stack account: every resource in betterstack.tf is counted out in that case,
# so the provider is configured but never called.
provider "betteruptime" {
  api_token = var.betterstack_api_token
}

# Uptime and Telemetry are separate APIs behind one token.
provider "logtail" {
  api_token = var.betterstack_api_token
}
