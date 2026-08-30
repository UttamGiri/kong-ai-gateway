variable "aws_region" {
  type        = string
  description = "AWS region for the AWS provider. IAM is global; this is still required."
  default     = "us-east-1"
}

variable "aws_profile" {
  type        = string
  description = "Named AWS CLI profile from IAM Identity Center (aws configure sso). Leave empty to use the default credential chain."
  default     = ""
}

variable "tfc_hostname" {
  type        = string
  description = "HCP Terraform hostname without a scheme."
  default     = "app.terraform.io"
}

variable "tfc_aws_audience" {
  type        = string
  description = "OIDC audience claim. Must match the IAM OIDC provider client ID."
  default     = "aws.workload.identity"
}

variable "tfc_organization_name" {
  type        = string
  description = "HCP Terraform org name used only as a string in the IAM trust sub claim. The org/workspaces do not need to exist for this apply."
}

variable "tfc_organization_email" {
  type        = string
  description = "Admin email used only when create_tfc_organization is true."
  default     = ""
}

variable "create_tfc_organization" {
  type        = bool
  description = "Create the HCP Terraform organization. Requires a user API token. Set false if the org already exists."
  default     = false
}

variable "tfc_project_name" {
  type        = string
  description = "HCP Terraform project to create and bind in the IAM trust policy."
  default     = "kong-ai-gateway"
}

variable "tfc_workspace_name" {
  type        = string
  description = "HCP Terraform workspace for workloads. State lives here from the first workload apply."
  default     = "kong-ai-gateway-aws-workload"
}

variable "tfc_bootstrap_workspace_name" {
  type        = string
  description = "HCP Terraform workspace that will hold bootstrap state after you migrate off local."
  default     = "kong-ai-gateway-aws-bootstrap"
}

variable "tfc_run_role_name" {
  type        = string
  description = "IAM role name that HCP Terraform assumes for plan and apply."
  default     = "hcp-terraform-run"
}

variable "tfc_run_role_policy_arns" {
  type        = list(string)
  description = "Managed policy ARNs attached to the run role. Scope this down after the first workloads land."
  default     = ["arn:aws:iam::aws:policy/AdministratorAccess"]
}
