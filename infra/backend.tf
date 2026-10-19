terraform {
  backend "s3" {
    bucket       = "on-the-edge-terraform-state"
    key          = "nextjs/terraform.tfstate"
    region       = "eu-north-1"
    use_lockfile = true
  }
}