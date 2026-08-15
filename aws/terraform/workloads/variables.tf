variable "aws_region" {
  type        = string
  description = "AWS region for workload resources."
  default     = "us-east-2"
}

variable "aws_profile" {
  type        = string
  description = "Named AWS CLI profile. Leave empty for HCP Terraform OIDC."
  default     = ""
}
