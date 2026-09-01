# The source the log shipper in every image posts to. Its token and host are
# computed, so creating the source and wiring it into the containers are one
# step rather than a value copied out of the UI into .env by hand.
resource "logtail_source" "homepage" {
  count = var.betterstack_api_token == "" ? 0 : 1

  name     = "homepage"
  platform = "http"

  # How a line is summarised in the live tail. One source carries three shapes:
  # nginx access records have status/method/path, chancery's slog has level/msg,
  # and anything not JSON arrives wrapped as message. Naming all of them lets a
  # row render whichever it has.
  live_tail_pattern = "{service} {level} {status} {method} {path} {msg} {message}"
}

# Two providers: betteruptime for monitors and the status page, logtail for the
# Telemetry source the containers ship logs to.
#
# local.monitoring gates the uptime side: before the domain is delegated the
# containers answer only on generated endpoints, and a monitor pinned to one
# would alert on the rename rather than on an outage.

resource "betteruptime_monitor_group" "homepage" {
  count = local.monitoring ? 1 : 0

  name       = "mdijkstra.dev"
  sort_index = 1
}

# Frequent because the site is min_scale 1: the check reaches an instance that
# was already running. The agent monitors below are not, hence their 15 minutes.
resource "betteruptime_monitor" "site" {
  count = local.monitoring ? 1 : 0

  url              = local.site_origin
  monitor_type     = "status"
  monitor_group_id = betteruptime_monitor_group.homepage[0].id

  pronounceable_name = "Homepage"
  check_frequency    = 180
  request_timeout    = 15
  regions            = ["eu"]

  # Scaleway renews the certificate it issued for the custom domain, and a failed
  # renewal is invisible until the browser refuses the site. These are the two
  # expiries nothing else in this repository watches.
  ssl_expiration    = 14
  domain_expiration = 30

  email = true
}

# Keyed on the PDF header rather than a status code: a truncated upload or a file
# replaced by an error page still answers 200. %PDF is the first four bytes of
# every valid PDF, so unlike a name out of the document it survives regenerating
# the file with another tool.
resource "betteruptime_monitor" "resume" {
  count = local.monitoring ? 1 : 0

  url              = "${local.site_origin}/resume.pdf"
  monitor_type     = "keyword"
  monitor_group_id = betteruptime_monitor_group.homepage[0].id

  pronounceable_name = "Resume PDF"
  required_keyword   = "%PDF"
  check_frequency    = 900
  request_timeout    = 15
  regions            = ["eu"]

  email = true
}

# Every check starts an instance, so a quarter-hour rather than three minutes:
# faster and the monitoring is an order of magnitude more traffic than the site.
resource "betteruptime_monitor" "agent_health" {
  count = local.monitor_agent ? 1 : 0

  url              = "https://agent.${var.domain}/health"
  monitor_type     = "status"
  monitor_group_id = betteruptime_monitor_group.homepage[0].id

  pronounceable_name = "Agent health"
  check_frequency    = 900
  request_timeout    = 30
  regions            = ["eu"]

  email = true
}

# The only check that reaches dragoman and the inference credential; /health
# passes while either is broken. Each run spends tokens, so it is created paused.
#
# 60s is the platform's ceiling for an HTTP monitor, well under the backend's own
# 500s budget, so this proves the fast path only: a run that hits chancery's
# rate-limit retries reports down while the stack is healthy.
resource "betteruptime_monitor" "agent_chat" {
  count = local.monitor_agent ? 1 : 0

  url              = "https://agent.${var.domain}/cv"
  monitor_type     = "expected_status_code"
  monitor_group_id = betteruptime_monitor_group.homepage[0].id

  pronounceable_name    = "Agent end to end"
  http_method           = "POST"
  expected_status_codes = [200]

  request_headers = [
    {
      name  = "Content-Type"
      value = "application/json"
    },
    # CORS_ORIGINS names the site, so this is the origin a visitor's browser sends.
    {
      name  = "Origin"
      value = local.site_origin
    },
  ]

  request_body = jsonencode({
    input = [
      {
        role    = "user"
        content = "Reply with the single word: ok"
      }
    ]
  })

  # Half-hourly is the platform's slowest permitted check; the allowed set is
  # [30, 45, 60, 120, 180, 300, 600, 900, 1800]. Paused, so it spends nothing.
  check_frequency = 1800
  request_timeout = 60
  regions         = ["eu"]

  paused = var.agent_chat_monitor_paused

  email = true
}

resource "betteruptime_status_page" "homepage" {
  count = local.status_page ? 1 : 0

  company_name = "mdijkstra"
  company_url  = local.site_origin
  timezone     = "UTC"
  subdomain    = var.status_page_subdomain
}

resource "betteruptime_status_page_section" "services" {
  count = local.status_page ? 1 : 0

  status_page_id = betteruptime_status_page.homepage[0].id
  name           = "Services"
  position       = 1
}

# The end-to-end check is deliberately absent: a paused, token-spending canary is
# not a service level to publish.
resource "betteruptime_status_page_resource" "site" {
  count = local.status_page ? 1 : 0

  status_page_id         = betteruptime_status_page.homepage[0].id
  status_page_section_id = betteruptime_status_page_section.services[0].id
  resource_id            = betteruptime_monitor.site[0].id
  resource_type          = "Monitor"
  public_name            = "Website"
  position               = 1
}

resource "betteruptime_status_page_resource" "resume" {
  count = local.status_page ? 1 : 0

  status_page_id         = betteruptime_status_page.homepage[0].id
  status_page_section_id = betteruptime_status_page_section.services[0].id
  resource_id            = betteruptime_monitor.resume[0].id
  resource_type          = "Monitor"
  public_name            = "Résumé"
  position               = 3
}

resource "betteruptime_status_page_resource" "agent" {
  count = local.status_page && var.backend_release != "" ? 1 : 0

  status_page_id         = betteruptime_status_page.homepage[0].id
  status_page_section_id = betteruptime_status_page_section.services[0].id
  resource_id            = betteruptime_monitor.agent_health[0].id
  resource_type          = "Monitor"
  public_name            = "Chat"
  position               = 2
}
