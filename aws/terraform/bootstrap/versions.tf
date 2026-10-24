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

  # State lives in HCP Terraform workspace kong-ai-gateway-aws-bootstrap.
  cloud {
    organization = "vaflt-org"

    workspaces {
      name = "kong-ai-gateway-aws-bootstrap"
    }
  }
}
