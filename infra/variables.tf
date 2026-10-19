variable "pr_number" {
  type    = string
  default = ""

  validation {
    condition     = var.pr_number == "" || can(regex("^[1-9][0-9]*$", var.pr_number))
    error_message = "pr_number must be empty (production) or a positive integer."
  }
}

variable "aws_region" {
  type    = string
  default = "eu-north-1"
}

variable "app_slug" {
  description = "Unique lowercase identifier for the application using this platform."
  type        = string
  default     = "deploy-aws"

  validation {
    condition     = can(regex("^[a-z0-9]+(-[a-z0-9]+)*$", var.app_slug)) && length(var.app_slug) <= 24
    error_message = "app_slug must contain lowercase letters, digits and single hyphens, and be at most 24 characters."
  }
}

variable "opennext_build_path" {
  description = "Absolute path to the application's .open-next build output."
  type        = string
  default     = "../.open-next"
}

variable "deploy_artifacts" {
  description = "Set to false only for destroy, so no local OpenNext build is required."
  type        = bool
  default     = true
}

locals {
  is_preview  = var.pr_number != ""
  environment = local.is_preview ? "pr-${var.pr_number}" : "production"
}