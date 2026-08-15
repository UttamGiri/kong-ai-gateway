# Workloads workspace (`kong-ai-gateway-aws-workload`)

HCP workflow: **CLI-Driven Workflow**.

Do **not** connect Version Control on this workspace. There is no GitHub repository, branch, or path filter to choose in HCP. Those fields exist only for the version-control workflow (bootstrap).

GitHub is wired through **Actions**, not HCP:

- [Terraform workloads](../../.github/workflows/terraform-workloads.yml)
- Actions → **Terraform workloads** → **Run workflow** → dropdown **plan** or **apply**
- A git push does **not** start this workflow
- Secret `TF_API_TOKEN` (HCP user token)
- Working directory in the Action: `aws/terraform/workloads`

Apply uses GitHub Environment `workloads` so you can require reviewers later. Plan uses Environment `plan` (no protection needed).
