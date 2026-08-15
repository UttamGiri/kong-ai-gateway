terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }

  # Phase 1: local state. Do not use the cloud backend until OIDC trust exists.
  # Phase 2: migrate this state to the bootstrap workspace on app.terraform.io.
  # See backend.cloud.tf.example and hcp-terraform-aws-bootstrap.md.
  backend "local" {
    path = "terraform.tfstate"
  }
}
