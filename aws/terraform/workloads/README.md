# Workloads workspace (`kong-ai-gateway-aws-workload`)

HCP workflow: **CLI-Driven Workflow**. Terraform root is **`dev/`**.

| Path | Role |
| --- | --- |
| [ARCHITECTURE.md](ARCHITECTURE.md) | Diagrams + daily cost |
| `dev/` | Terraform: VPC, subnet, EKS |
| `prod/` | Empty |

GitHub Action working directory: `aws/terraform/workloads/dev`. Run from branch **`develop`**.
