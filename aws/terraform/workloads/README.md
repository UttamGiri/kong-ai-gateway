# Workloads workspace (`kong-ai-gateway-aws-workload`)

HCP workflow: **CLI-Driven**. Terraform root is **`dev/`**.

| Path | Role |
| --- | --- |
| [ARCHITECTURE.md](ARCHITECTURE.md) | Diagrams + daily cost |
| `dev/` | Terraform: VPC, subnet, EKS |
| `prod/` | Empty |

GitHub Action: **Actions → Terraform workloads → Run workflow** (branch **`develop`**). Working directory `aws/terraform/workloads/dev`.
