output "oidc_provider_arn" {
  description = "IAM OIDC provider for app.terraform.io. Used by HCP Terraform dynamic AWS credentials."
  value       = aws_iam_openid_connect_provider.tfc.arn
}

output "tfc_run_role_arn" {
  description = "IAM role HCP Terraform assumes via OIDC. Set this as TFC_AWS_RUN_ROLE_ARN on the workspace."
  value       = aws_iam_role.tfc_run.arn
}

output "iam_trust_sub_bootstrap" {
  description = "OIDC sub claim this role trusts for the bootstrap workspace name (workspace need not exist yet)."
  value       = "organization:${var.tfc_organization_name}:project:${var.tfc_project_name}:workspace:${var.tfc_bootstrap_workspace_name}:run_phase:*"
}

output "iam_trust_sub_workloads" {
  description = "OIDC sub claim this role trusts for the workloads workspace name (workspace need not exist yet)."
  value       = "organization:${var.tfc_organization_name}:project:${var.tfc_project_name}:workspace:${var.tfc_workspace_name}:run_phase:*"
}
