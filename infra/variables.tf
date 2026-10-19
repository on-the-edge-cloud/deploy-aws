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

variable "deploy_artifacts" {
  description = "Set to false only for destroy, so no local OpenNext build is required."
  type        = bool
  default     = true
}

locals {
  is_preview  = var.pr_number != ""
  environment = local.is_preview ? "pr-${var.pr_number}" : "production"
}