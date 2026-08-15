# Workloads workspace (`kong-ai-gateway-aws-workload`)

HCP workflow: **CLI-Driven Workflow**.

Do **not** connect Version Control on this workspace. There is no GitHub repository, branch, or path filter to choose in HCP. Those fields exist only for the version-control workflow (bootstrap).

GitHub is wired through **Actions**, not HCP:

- [Terraform workloads](../../.github/workflows/terraform-workloads.yml) — Actions → Run workflow
- Secret `TF_API_TOKEN` (HCP user token)
- Working directory in the Action: `aws/terraform/workloads`

A git push does not start this workspace. Bootstrap (`kong-ai-gateway-aws-bootstrap`) is the VCS-connected workspace; see [hcp-terraform-aws-bootstrap.md](../hcp-terraform-aws-bootstrap.md#choose-your-workflow-hcp-workspace-settings).
