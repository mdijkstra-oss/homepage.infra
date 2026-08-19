# The zone itself is not declared here. It is created by adding the domain to
# Domains and DNS as an external domain, which is a console flow gated on a
# TXT challenge — the registration stays with the registrar, only the zone moves.
# These records are written into that zone.
#
# 300-second TTLs throughout: every record here names a container endpoint that
# a redeploy can move, and a short TTL is what makes a rollback take minutes.

# --- Hosting: site and agent containers -------------------------------------

resource "scaleway_domain_record" "apex" {
  count = local.site_dns ? 1 : 0

  # ALIAS rather than CNAME because the apex already carries SOA and NS records,
  # which a CNAME may not coexist with. Scaleway resolves it like a CNAME.
  dns_zone = var.domain
  name     = ""
  type     = "ALIAS"
  data     = local.site_endpoint
  ttl      = 300
}

resource "scaleway_domain_record" "www" {
  count = local.site_dns ? 1 : 0

  # Points at the container rather than at the apex: the container answers on
  # both names and redirects this one, and a chain through the ALIAS would make
  # the certificate challenge depend on two records resolving instead of one.
  dns_zone = var.domain
  name     = "www"
  type     = "CNAME"
  data     = local.site_endpoint
  ttl      = 300
}

resource "scaleway_domain_record" "agent" {
  count = local.agent_dns ? 1 : 0

  dns_zone = var.domain
  name     = "agent"
  type     = "CNAME"
  data     = local.backend_endpoint
  ttl      = 300
}

# --- Mail: hey.com -------------------------------------------------------

resource "scaleway_domain_record" "mail_exchange" {
  for_each = var.domain == "" ? {} : { for i, mx in local.mail_exchange : i => mx }

  dns_zone = var.domain
  name     = ""
  type     = "MX"
  data     = each.value
  priority = 10 * (tonumber(each.key) + 1)
  ttl      = 300
}

resource "scaleway_domain_record" "hey_verification" {
  count = var.domain == "" ? 0 : 1

  dns_zone = var.domain
  name     = ""
  type     = "TXT"
  data     = "hey-verification:TGy4hUcfRmfg6hRrCiyEFvwu"
  ttl      = 300
}

resource "scaleway_domain_record" "hey_verification_spf1" {
  count = var.domain == "" ? 0 : 1

  dns_zone = var.domain
  name     = ""
  type     = "TXT"
  data     = "v=spf1 include:_spf.hey.com ~all"
  ttl      = 300
}

resource "scaleway_domain_record" "dmarc" {
  count = var.domain == "" ? 0 : 1

  dns_zone = var.domain
  name     = "_dmarc"
  type     = "TXT"
  data     = "v=DMARC1; p=none;"
  ttl      = 300
}

resource "scaleway_domain_record" "hey_dkim" {
  count = var.domain == "" ? 0 : 1

  dns_zone = var.domain
  name     = "heymail._domainkey"
  type     = "CNAME"
  data     = "heymail._domainkey.hey.com."
  ttl      = 300
}

# --- Legacy: old host, kept reachable by name ---------------------------

resource "scaleway_domain_record" "legacy" {
  for_each = var.domain == "" ? {} : local.legacy_records

  dns_zone = var.domain
  name     = each.key
  type     = "A"
  data     = each.value
  ttl      = 300

  lifecycle {
    # Dropping a key from local.legacy_records reads as tidying up, and the
    # plan for it looks like one line. It is how the persistence directory on
    # the old host stops being reachable by name. Deleting one of these takes
    # two commits: remove this block, then remove the key.
    prevent_destroy = true
  }
}
