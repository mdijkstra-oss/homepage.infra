locals {
  name_prefix     = "${var.project}-${var.env}"
  main_project_id = var.project_id

  registry_push_app_id = scaleway_iam_application.registry_push.id

  # Both release workflows only ever produce tags of this shape.
  release_tag_pattern = "^v[0-9]+\\.[0-9]+\\.[0-9]+$"

  site_image_name    = "homepage-site"
  backend_image_name = "homepage-backend"

  site_image    = "${scaleway_registry_namespace.main.endpoint}/${local.site_image_name}:${var.site_release}"
  backend_image = "${scaleway_registry_namespace.main.endpoint}/${local.backend_image_name}:${var.backend_release}"

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

  # Mail is not part of this stack: the mailboxes and the forwarding stay with
  # the registrar's mail platform, and these two records are all that points at
  # it. Nothing here creates or reads them beyond keeping them in the zone.
  mail_exchange = "mdijkstra-dev.netcup-mail.de."
  mail_host     = "46.38.243.234"

  # Names still served by the machine this stack replaces. They are carried
  # across so that repointing the registrar changes nothing observable. Delete
  # this map once nothing answers on that host.
  legacy_host = "159.195.21.135"
  legacy_records = {
    "api"          = local.legacy_host
    "hermes"       = local.legacy_host
    "hermes-logos" = local.legacy_host
    "hermes-mcp"   = local.legacy_host
    "hermes-relay" = local.legacy_host
    "ftp"          = local.mail_host
  }
}
