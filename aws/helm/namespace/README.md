# Namespace Helm chart

Creates two Kubernetes namespaces. Run this **before** Argo CD.

| Namespace object | Purpose |
| --- | --- |
| `argocd` | Where Argo CD pods go |
| `kong-ai-gateway` | Kong + Istio sidecar (`istio-injection: enabled`) |

## Terraform + Helm

| What | Tool |
| --- | --- |
| EKS access entries | **Terraform** `aws/terraform/workloads/dev/infra/access_entries.tf` |
| Namespaces | **Helm** this chart |

Apply Terraform first, then:

```bash
./aws/helm/namespace/install.sh
```

`install.sh` only writes kubeconfig and runs Helm. It does **not** create access entries.

`--namespace kube-system` on Helm is only where this **release Secret** is stored. The script still creates cluster objects named `argocd` and `kong-ai-gateway`. You cannot install this chart with `--namespace argocd` because that namespace does not exist yet.

Full connect / kubeconfig / console vs kubectl: **[CONNECT.md](CONNECT.md)**.

End-to-end namespace automation (IAM group → access entry → RoleBinding → EKS vs GKE vs OpenShift, Terraform vs Helm): **[NAMESPACE-AUTOMATION.md](NAMESPACE-AUTOMATION.md)**.
