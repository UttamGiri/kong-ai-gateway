# Dev Terraform

Root module for HCP workspace `kong-ai-gateway-aws-workload`.

Creates **AWS only**: VPC, public subnets, EKS, node group. Namespaces and Kong are Helm.

## Destroy switch

Do not comment out or delete `.tf` files.

| `enabled` | Next apply |
| --- | --- |
| `true` (default) | Create / keep the demo stack |
| `false` | **Hard-delete** the whole module (nodes, EBS volumes, cluster, VPC) |

GitHub Action: **Run workflow** → **apply** → uncheck **enabled**.

See [DESTROY.md](DESTROY.md) for the full create list, daily cost, and which switches to set **false**.  
See [RECREATE.md](RECREATE.md) for destroy → create again (no soft delete).

Default worker: **1 × t3.medium** (one public IPv4). Set `node_instance_type` on the HCP workspace if you need to change it.

## $20 / month billing alert

Terraform creates an AWS Budget (`budget_limit_usd = 20`). It is **not** removed when `enabled = false`.

Set **`budget_alert_email`** on the HCP workspace (or in tfvars), apply, then confirm the email AWS sends. Alerts at 50%, 80%, and 100% actual, plus 100% forecasted.
