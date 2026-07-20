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

variable "owner_user_id" {
  type        = string
  description = "Owner user ID, used as the full-access principal in bucket policies."
}

variable "api_key_expires_at" {
  type        = string
  description = "RFC3339 expiry for generated API keys. Org policy requires one; rotate before it lapses."
}
