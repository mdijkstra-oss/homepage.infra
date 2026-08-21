# Non-secret identifiers — safe to commit (a project/org ID is not a credential).
project_id      = "48cc48c7-4a2f-4a71-8bbe-b6069252dff4"
organization_id = "48cc48c7-4a2f-4a71-8bbe-b6069252dff4"
region          = "nl-ams"

api_key_expires_at = "2027-07-20T00:00:00Z"

# Deploying is changing a pin; rolling back is changing it back. Empty means
# nothing is live yet. The DeepSeek key is not here — export it as
# TF_VAR_deepseek_api_key.
#
# site_release names an image, not a tarball. v1.0.2 and everything before it
# were tarballs, so the first value here is the first tag cut after the site
# repo grew a Dockerfile.
site_release    = "v1.1.13"
backend_release = "v0.1.9"

# The translator between the backend and Scaleway. Empty puts the backend back
# on OpenAI and destroys the container.
dragoman_release = "v0.1.0"

# Set once the domain has been added to Domains and DNS as an external domain
# and its ownership challenge has passed. Setting it writes the zone; nothing is
# served on it until domain_delegated follows.
domain = "mdijkstra.dev"

# Set once the registrar points at ns0.dom.scw.cloud and ns1.dom.scw.cloud.
# Until then the certificate challenge resolves to the old host and fails.
domain_delegated = true
