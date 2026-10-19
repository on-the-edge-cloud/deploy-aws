variable "pr_number" {
  type    = string
  default = ""
}

locals {
  is_preview     = var.pr_number != ""
  environment    = local.is_preview ? "pr-${var.pr_number}" : "production"
  resource_prefix = local.is_preview ? "pr-${var.pr_number}-" : "prod-"
}