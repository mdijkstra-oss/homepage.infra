variable "project_id" {
  type        = string
  description = "Project ID that owns these resources."
}

variable "organization_id" {
  type        = string
  description = "Organization ID."
}

variable "region" {
  type        = string
  default     = "nl-ams"
  description = "Cloud region for regional resources (Amsterdam)."
}

variable "project" {
  type        = string
  default     = "homepage"
  description = "Logical project name, used as a naming prefix."
}

variable "env" {
  type        = string
  default     = "prod"
  description = "Environment name. Single env for now; parameterized for later."
}

variable "api_key_expires_at" {
  type        = string
  description = "RFC3339 expiry for generated API keys. Org policy requires one; rotate before it lapses."
}

# Every variable below defaults rather than being required. A variable with no
# default never reaches its own validation block — tofu prompts on a TTY, or
# fails with "No value for required variable" — so defaulting to empty is what
# makes the rule run. `-input=false` in the Makefile turns the prompt into an
# error.

variable "site_release" {
  type        = string
  default     = ""
  description = "Image tag in the registry namespace that the site container runs. Empty creates no container."

  validation {
    condition     = var.site_release == "" || can(regex(local.release_tag_pattern, var.site_release))
    error_message = "site_release must be empty or a tag of the form v<major>.<minor>.<patch>, for example v1.2.3."
  }
}

variable "domain" {
  type        = string
  default     = ""
  description = "Domain whose DNS zone this configuration manages, and under which the containers are published. Empty creates no records and no custom domains."

  validation {
    condition     = var.domain == "" || can(regex("^[a-z0-9-]+\\.[a-z]{2,}$", var.domain))
    error_message = "domain must be empty or a bare registrable domain such as example.dev — not a subdomain and not a URL."
  }
}

variable "domain_delegated" {
  type        = bool
  default     = false
  description = "Whether the registrar already points this domain at Scaleway's nameservers. Publishing a custom domain runs an HTTP-01 challenge against public DNS, so it fails until this is true."

  validation {
    condition     = !var.domain_delegated || var.domain != ""
    error_message = "domain_delegated is set but domain is empty, so there is nothing to delegate."
  }
}

variable "backend_release" {
  type        = string
  default     = ""
  description = "Image tag in the registry namespace that the container runs. Empty creates no container."

  validation {
    condition     = var.backend_release == "" || can(regex(local.release_tag_pattern, var.backend_release))
    error_message = "backend_release must be empty or a tag of the form v<major>.<minor>.<patch>, for example v1.2.3."
  }
}

variable "backend_max_scale" {
  type        = number
  default     = 3
  description = "Upper bound on container instances."

  validation {
    condition     = var.backend_max_scale == floor(var.backend_max_scale) && var.backend_max_scale >= 1 && var.backend_max_scale <= 10
    error_message = "backend_max_scale must be a whole number between 1 and 10."
  }
}

variable "openai_api_key" {
  type        = string
  sensitive   = true
  default     = ""
  description = "OpenAI API key. Reaches the container as the secret environment variable RESPONSES_AUTH_TOKEN."

  validation {
    condition     = var.openai_api_key == trimspace(var.openai_api_key)
    error_message = "openai_api_key must carry no surrounding whitespace; a trailing newline authenticates as a different string and fails only at the first inference call."
  }
}
