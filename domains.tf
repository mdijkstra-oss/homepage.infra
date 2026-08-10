# Publishing a hostname on a container is what makes Scaleway issue and renew a
# certificate for it. The check behind it is an HTTP-01 challenge against public
# DNS, which gives up after three minutes — so each binding waits on its own
# record, and all of them wait on the registrar pointing here at all.

resource "scaleway_container_domain" "apex" {
  count = local.publish_site ? 1 : 0

  container_id = scaleway_container.site[0].id
  hostname     = var.domain
  region       = var.region

  depends_on = [scaleway_domain_record.apex]
}

resource "scaleway_container_domain" "www" {
  count = local.publish_site ? 1 : 0

  # Bound even though it only ever redirects: the redirect is served by the
  # container over HTTPS, so this name needs a certificate of its own.
  container_id = scaleway_container.site[0].id
  hostname     = "www.${var.domain}"
  region       = var.region

  depends_on = [scaleway_domain_record.www]
}

resource "scaleway_container_domain" "agent" {
  count = local.publish_agent ? 1 : 0

  container_id = scaleway_container.backend[0].id
  hostname     = "agent.${var.domain}"
  region       = var.region

  depends_on = [scaleway_domain_record.agent]
}
