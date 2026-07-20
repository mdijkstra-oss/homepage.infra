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
