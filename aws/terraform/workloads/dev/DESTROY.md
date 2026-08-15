# Dev stack: what it creates, cost, and how to turn it off

Workspace: **kong-ai-gateway-aws-workload**  
Terraform root: `aws/terraform/workloads/dev`  
Region: **us-east-2**

Do not comment out or delete `.tf` files. Use the **`enabled`** switch, then **apply**.

---

## What Terraform creates (`enabled = true`)

| Layer | Resources |
| --- | --- |
| Network | 1 VPC `10.20.0.0/16`, 1 IGW, 1 public route table, **2 public subnets** (nodes in one AZ, EKS ENI in the second — AWS requires two) |
| Compute | EKS cluster `kong-ai-dev` (v1.31), node group `demo`: **1 × t3.medium**, 20 GB gp3 (**one** public IPv4 on that node) |
| IAM | Cluster role, node role, policy attachments |
| Launch template | EBS `delete_on_termination = true` |

**Not created here:** namespaces, Argo CD, Kong, Istio, Docker Registry, NAT, NLB.

---

## Cost calculator (us-east-2, on-demand Linux, list price)

Hours in a day = **24**. Days in a month ≈ **30**.

### Unit rates (plug these in)

| Meter | Rate | Source |
| --- | --- | --- |
| EKS cluster | **$0.10 / hour** | [EKS pricing](https://aws.amazon.com/eks/pricing/) |
| `t3.small` | **$0.0208 / hour** | cheaper, 2 GB — may OOM |
| `t3.medium` | **$0.0416 / hour** | **demo default** (4 GB) |
| `t3.large` | **$0.0832 / hour** | oversized for this demo |
| gp3 EBS | **$0.08 / GB-month** | 20 GB × node count |
| Public IPv4 | **$0.005 / IP / hour** | **one IP per node** in the public subnet |
| NLB | **$0.0225 / hour** | only after Istio/ingress (not this Terraform) |
| NAT Gateway | **$0.045 / hour** + **$0.045 / GB** | **do not enable** |

### Formulas

```text
eks_day          = 0.10 × 24
nodes_day        = node_desired_size × instance_hourly × 24
ebs_day          = node_desired_size × 20 × 0.08 / 30
ipv4_day         = node_desired_size × 0.005 × 24
nlb_day          = 0.0225 × 24          # optional, Helm/Istio later
nat_day          = 0.045 × 24           # optional, avoid

terraform_day    = eks_day + nodes_day + ebs_day + ipv4_day
month            = terraform_day × 30
```

Terraform variables that change the bill:

| Variable | Default | Effect |
| --- | --- | --- |
| `enabled` | `true` | `false` → destroy → **$0/day** for this stack |
| `node_instance_type` | `t3.medium` | `t3.small` to save ~$0.50/day |
| `node_desired_size` | `1` | Each extra node adds **another** public IPv4 + instance + disk |

### What “public IPv4” means

A **public IPv4** is an internet address (`3.x.x.x`) attached to a machine so it can talk to the internet **without NAT**.

- **1 worker node** in a public subnet → **1 public IPv4** (~$0.12/day). That is the current design.
- **2 worker nodes** → **2 public IPv4s** (~$0.24/day). That is why the old estimate said “2 public IPv4”. It was two computers, not two addresses on one computer.
- **2 subnets** is not 2 node IPs. The second subnet only holds EKS control-plane ENIs (AWS requirement). It does not add a second worker.

You cannot assign one public IPv4 to two EC2 nodes. Putting nodes in a private subnet avoids node IPv4 charges but needs a **NAT Gateway** (~$1.08/day), which is more expensive.

### Worked example — current defaults (`enabled=true`, **1 × t3.medium**)

| Line | Calculation | $/day |
| --- | --- | --- |
| EKS | 0.10 × 24 | **2.40** |
| Nodes | 1 × 0.0416 × 24 | **1.00** |
| EBS | 1 × 20 × 0.08 / 30 | **0.05** |
| IPv4 | 1 × 0.005 × 24 | **0.12** |
| VPC / IGW / IAM | — | **0.00** |
| **This Terraform** | | **~3.57** |
| **× 30 days** | | **~107 / month** |

### Optional add-ons (not in this apply)

| Add-on | Calculation | Extra $/day | Running total / day |
| --- | --- | --- | --- |
| Istio NLB + 1 extra IPv4 | (0.0225 × 24) + (0.005 × 24) | ~0.66 | **~4.23** |
| NAT Gateway (avoid) | 0.045 × 24 (+ data) | ~1.08+ | **~4.65+** |
| Second node (2 × t3.medium) | +1.00 +0.05 +0.12 | +1.17 | **~4.74** |

### `enabled = false` (after apply)

| Line | $/day |
| --- | --- |
| This demo stack | **0.00** |
| Bootstrap OIDC + IAM role | **0.00** (not destroyed) |
| $20 AWS Budget | **0.00** (kept on purpose; first two budgets are free) |

Prices are AWS list rates, not a quote. Confirm in **Billing → Cost Explorer** after the first day.

---

## $20 / month billing alert

Account-wide AWS Budget at **$20 USD / month**. This stack is ~$107/month if left on, so the alert is a tripwire (around day 6).

| Variable | Default | What to do |
| --- | --- | --- |
| `budget_limit_usd` | `20` | Leave at 20 |
| `budget_alert_email` | `""` | Set your email on the HCP workspace, apply, **confirm the AWS email** |

Emails fire at **50%** ($10), **80%** ($16), **100% actual**, and **100% forecasted**.

`enabled = false` does **not** delete this budget. To remove the alert, delete `budget.tf` or clear it in AWS Budgets.

---

## What to set to **false** to destroy everything

Only **one** Terraform variable tears the stack down: **`enabled`**.

Set **`enabled = false`** in **every place that would otherwise force it true**, then run **apply** (not plan-only).

| Where | What to turn **false** | Leave alone |
| --- | --- | --- |
| **GitHub Action** (preferred) | Input **`enabled`** → uncheck / `false` | Command = **`apply`** (not `plan`) |
| **HCP workspace** Variables | Terraform variable **`enabled`** → `false` | `TFC_AWS_PROVIDER_AUTH`, `TFC_AWS_RUN_ROLE_ARN`, `AWS_REGION`, `aws_region`, `budget_limit_usd`, `budget_alert_email` stay as they are |
| **Local `terraform.tfvars`** (if you use it) | `enabled = false` | — |

### GitHub Action (do this)

1. Actions → **Terraform workloads** → **Run workflow**
2. Branch: **`develop`**
3. **command** = `apply`
4. **enabled** = **false**
5. Run

`TF_VAR_enabled` from the Action overrides the HCP default for that run.

### HCP UI apply (if you apply in Terraform Cloud)

Variables → Terraform variables → **`enabled`** = **false** → queue **apply**.

Set it back to **`true`** before the next create, or the next apply will stay empty.

---

## What **false** does

`module.demo` uses `count = var.enabled ? 1 : 0`.

`enabled = false` + apply → Terraform **destroys** VPC, subnets, IGW, EKS, nodes, EBS volumes, IAM roles for this stack. Hard delete (no soft-delete, no KMS pending window).

Helm objects (namespaces, Kong, Istio LBs) are not in this state. Destroy still tries to delete ELBs tagged for this cluster so the VPC can finish.

---

## Do **not** set these to false to destroy

| Variable | Why |
| --- | --- |
| `TFC_AWS_PROVIDER_AUTH` | Needed so HCP can still assume the role to **delete** AWS |
| `TFC_AWS_RUN_ROLE_ARN` | Same |
| Bootstrap / OIDC | Different workspace; not part of this demo bill |

If AWS auth is off, apply cannot destroy.

Destroy then create again: [RECREATE.md](RECREATE.md).
