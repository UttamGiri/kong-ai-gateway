# Destroy and create again (no soft delete)

State lives in HCP Terraform workspace **kong-ai-gateway-aws-workload**.  
Switch: **`enabled`**. Do not comment out `.tf` files.

**Yes — destroy, then apply with `enabled = true` again, and it works.** These resources are hard-deleted. Nothing sits in Recycle Bin or “pending delete” (we did not create customer KMS keys or RDS).

---

## Cycle

```text
enabled = true  + apply  →  create VPC, EKS, 1 × t3.medium
enabled = false + apply  →  hard-delete that stack (wait until apply is green)
enabled = true  + apply  →  create a new stack (same names, new IDs)
```

HCP workspace **kong-ai-gateway-aws-workload** (branch **`develop`**):

| Step | Variable `enabled` | Then |
| --- | --- | --- |
| Create | `true` | Start new run → Confirm & Apply |
| Destroy | `false` | Start new run → Confirm & Apply |
| Create again | `true` | Wait until destroy is green, then Start new run → Confirm & Apply |

If you apply `true` while destroy is still running, AWS may reject the cluster name. Wait for the destroy apply to finish, then apply `true`.

---

## Soft delete?

| Resource | Soft delete? | Recreate same names? |
| --- | --- | --- |
| VPC, subnets, IGW, routes | No | Yes (new IDs) |
| EKS cluster `kong-ai-dev` | No | Yes, after delete finishes (~10–15 min) |
| Node, 20 GB gp3 disk | No (`delete_on_termination = true`) | Yes |
| Launch template | No | Yes (`name_prefix`) |
| IAM roles `kong-ai-dev-cluster` / `-nodes` | No | Yes; wait ~1 min if `EntityAlreadyExists` |
| Node public IPv4 | Released to Amazon | New address next time |
| Customer KMS / RDS | **Not created** | Those would be the 7–30 day hold |
| $20 AWS Budget | **Not destroyed** | Stays on purpose |

Helm / Argo CD / Kong / Istio are **not** in this Terraform state. They go away with the cluster. Install them again on the new cluster.

---

## What `enabled = false` does not delete

- HCP state file (it updates to “empty module”, it is not wiped)
- Bootstrap OIDC + `hcp-terraform-run` (other workspace)
- AWS Budget `$20/month` (`budget.tf` is outside `module.demo`)

---

See [DESTROY.md](DESTROY.md) for cost and where to flip `enabled`.
