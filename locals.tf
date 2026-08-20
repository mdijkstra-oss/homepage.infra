locals {
  name_prefix     = "${var.project}-${var.env}"
  main_project_id = var.project_id

  registry_push_app_id = scaleway_iam_application.registry_push.id
  inference_app_id     = scaleway_iam_application.inference.id
  invoke_app_id        = one(scaleway_iam_application.invoke[*].id)

  # Generative APIs scopes its endpoint by project, so the project id sits in the
  # path rather than in a header. The translator holds this URL in its own service
  # table; it is here so that a project id lives in one place per repository.
  inference_base_url = "https://api.scaleway.ai/${local.main_project_id}/v1"

  # Both release workflows only ever produce tags of this shape.
  release_tag_pattern = "^v[0-9]+\\.[0-9]+\\.[0-9]+$"

  site_image_name     = "homepage-site"
  backend_image_name  = "homepage-backend"
  dragoman_image_name = "homepage-dragoman"

  site_image     = "${scaleway_registry_namespace.main.endpoint}/${local.site_image_name}:${var.site_release}"
  backend_image  = "${scaleway_registry_namespace.main.endpoint}/${local.backend_image_name}:${var.backend_release}"
  dragoman_image = "${scaleway_registry_namespace.main.endpoint}/${local.dragoman_image_name}:${var.dragoman_release}"

  # Where the backend POSTs; chancery appends /responses to it. With a translator
  # deployed it goes through it and reaches Scaleway, whose catalogue answers on
  # /chat/completions. Without one it calls OpenAI directly, which is where the
  # backend answered before the translator existed and where clearing
  # dragoman_release puts it back.
  dragoman_deployed = var.dragoman_release != ""
  dragoman_endpoint = one(scaleway_container.dragoman[*].public_endpoint)
  backend_base_url  = local.dragoman_deployed ? local.dragoman_endpoint : local.openai_base_url

  openai_base_url = "https://api.openai.com/v1"

  # The site answers on the bare domain; the container redirects www to it, so a
  # browser only ever sends one Origin and the backend allows one value. Before
  # a domain is set the site is only reachable on its generated endpoint, which
  # is then the only origin a browser can send.
  site_origin = var.domain != "" ? "https://${var.domain}" : (
    local.site_endpoint == null ? "" : "https://${trimsuffix(local.site_endpoint, ".")}"
  )

  # public_endpoint carries a scheme, and a CNAME or ALIAS wants a bare hostname
  # with the trailing dot that makes it absolute. Built through a comprehension
  # rather than an index so that an undeployed half yields null instead of an
  # error while the expression is still evaluated.
  site_endpoint    = one([for e in scaleway_container.site[*].public_endpoint : "${trimprefix(e, "https://")}."])
  backend_endpoint = one([for e in scaleway_container.backend[*].public_endpoint : "${trimprefix(e, "https://")}."])

  # A record can only name a container that exists, and a custom domain can only
  # be published once public DNS already resolves to that container — which is
  # not true until the registrar has been repointed at Scaleway.
  site_dns      = var.domain != "" && var.site_release != ""
  agent_dns     = var.domain != "" && var.backend_release != ""
  publish_site  = local.site_dns && var.domain_delegated
  publish_agent = local.agent_dns && var.domain_delegated

  # Mail is not part of this stack: the mailboxes stay with hey.com, and the
  # records below are all that points at it. Nothing here creates or reads
  # them beyond keeping them in the zone.
  mail_exchange = ["work-mx.app.hey.com."]

  # Names still served by the machine this stack replaces, carried across so
  # that repointing the registrar changed nothing observable.
  #
  # They are not spare parts. hermes-relay is how that machine is reached to
  # copy its persistence directory off, and a name that stops resolving turns
  # that into a hang rather than a clean failure. Delete the map once the data
  # is off the box and the box itself is gone.
  legacy_host = "159.195.21.135"
  legacy_records = {
    "api"          = local.legacy_host
    "hermes"       = local.legacy_host
    "hermes-logos" = local.legacy_host
    "hermes-mcp"   = local.legacy_host
    "hermes-relay" = local.legacy_host
  }
}
