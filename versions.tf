terraform {
  required_version = ">= 1.10"

  required_providers {
    scaleway = {
      source  = "scaleway/scaleway"
      version = "~> 2.0"
    }

    betteruptime = {
      source  = "BetterStackHQ/better-uptime"
      version = "~> 0.21.13"
    }

    logtail = {
      source  = "BetterStackHQ/logtail"
      version = "~> 11.1"
    }
  }

  backend "s3" {
    bucket = "mdijkstra-homepage-tfstate"
    key    = "homepage/terraform.tfstate"
    region = "nl-ams"

    endpoints = {
      s3 = "https://s3.nl-ams.scw.cloud"
    }

    skip_credentials_validation = true
    skip_region_validation      = true
    skip_requesting_account_id  = true
    skip_metadata_api_check     = true
    skip_s3_checksum            = true

    use_lockfile = true
  }
}
