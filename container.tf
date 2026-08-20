resource "scaleway_container_namespace" "main" {
  name        = local.name_prefix
  description = "Serverless containers for the homepage stack."
  region      = var.region
  project_id  = local.main_project_id
}

resource "scaleway_container" "site" {
  count = var.site_release == "" ? 0 : 1

  name         = "${local.name_prefix}-site"
  namespace_id = scaleway_container_namespace.main.id
  region       = var.region

  image = local.site_image
  port  = 8080

  # The smallest instance the platform offers, held warm. A static site that
  # cold-starts is worse than one that costs a little, and the two containers
  # together still fit inside the monthly free allowance.
  min_scale = 1
  max_scale = 3

  memory_limit_bytes = 128 * 1000 * 1000
  cpu_limit          = 70

  privacy = "public"

  liveness_probe {
    http {
      path = "/healthz"
    }

    failure_threshold = 3
    interval          = "10s"
    timeout           = "5s"
  }
}

resource "scaleway_container" "backend" {
  count = var.backend_release == "" ? 0 : 1

  name         = "${local.name_prefix}-backend"
  namespace_id = scaleway_container_namespace.main.id
  region       = var.region

  image = local.backend_image
  port  = 8081

  min_scale = 0
  max_scale = var.backend_max_scale

  # One in-flight request per instance, so max_scale bounds simultaneous
  # inferences rather than instances that each queue several.
  scaling_option {
    concurrent_requests_threshold = 1
  }

  # Above every bound chancery can spend before it answers, so the platform never
  # cuts first. The rate-limit path dominates: three attempts, each able to honour
  # a Retry-After up to its 2-minute ceiling plus 10% jitter, is ~396s before the
  # 429 is even produced, and a stream that then starts adds the 90s stall
  # allowance. Cut at 300 instead and the platform's own gateway error replaces
  # chancery's — carrying no CORS header, so the browser reports it as a failed
  # fetch and the rate-limit message the site renders is never reached.
  timeout = 500

  # 512 MB paired with 280 mvCPU, from the provider's memory-to-vCPU table.
  # The provider reads this attribute as decimal bytes.
  memory_limit_bytes = 512 * 1000 * 1000
  cpu_limit          = 280

  # Browsers call this directly; the private-container mechanism wants an IAM
  # key in an X-Auth-Token header, which a web client cannot hold.
  privacy = "public"

  # With a translator deployed the backend holds no model-provider key at all: it
  # authenticates to that container's gateway and nothing further. Without one it
  # calls OpenAI directly and holds that key itself, so both pairs are conditional
  # rather than one of them always being set.
  environment_variables = {
    RESPONSES_BASE_URL       = local.backend_base_url
    RESPONSES_GATEWAY_HEADER = local.dragoman_deployed ? "X-Auth-Token" : ""
    CORS_ORIGINS             = local.site_origin
    ENV                      = "production"
    LOG_LEVEL                = "info"
  }

  secret_environment_variables = {
    RESPONSES_AUTH_TOKEN    = local.dragoman_deployed ? "" : var.openai_api_key
    RESPONSES_GATEWAY_TOKEN = local.dragoman_deployed ? one(scaleway_iam_api_key.invoke[*].secret_key) : ""
  }

  liveness_probe {
    http {
      path = "/health"
    }

    failure_threshold = 3
    interval          = "10s"
    timeout           = "5s"
  }
}

resource "scaleway_container" "dragoman" {
  count = var.dragoman_release == "" ? 0 : 1

  name         = "${local.name_prefix}-dragoman"
  namespace_id = scaleway_container_namespace.main.id
  region       = var.region

  image = local.dragoman_image
  port  = 8080

  min_scale = 0
  max_scale = var.backend_max_scale

  # One in-flight request per instance, matching the backend: this container is
  # blocked on the provider for the whole of a request, so an instance serving
  # several would queue them behind each other.
  scaling_option {
    concurrent_requests_threshold = 1
  }

  # Under the backend's 500, so that a provider which never answers is cut here
  # and the error a browser receives is chancery's, carrying its CORS header,
  # rather than the platform's own gateway error in front of the backend.
  timeout = 450

  # Translation is JSON in and JSON out with no model of its own to hold, so the
  # smallest pairing in the provider's memory-to-vCPU table is enough. The
  # provider reads this attribute as decimal bytes.
  memory_limit_bytes = 256 * 1000 * 1000
  cpu_limit          = 140

  # Private: Scaleway's gateway rejects a request carrying no valid X-Auth-Token
  # before it reaches this container. Only the backend holds that key, which is
  # what keeps the container carrying the Generative APIs credential off the open
  # internet without dragoman authenticating anything itself.
  privacy = "private"

  secret_environment_variables = {
    SCALEWAY_API_KEY = scaleway_iam_api_key.inference.secret_key
  }

  liveness_probe {
    http {
      path = "/health"
    }

    failure_threshold = 3
    interval          = "10s"
    timeout           = "5s"
  }
}
