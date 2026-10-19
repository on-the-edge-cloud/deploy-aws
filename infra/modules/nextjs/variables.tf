variable "name" {
  type = string
}

variable "build_path" {
  type = string
}

variable "deploy_artifacts" {
  type    = bool
  default = true
}

variable "force_destroy" {
  type    = bool
  default = false
}