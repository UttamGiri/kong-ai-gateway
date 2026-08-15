# Namespace Helm chart

Creates two Kubernetes namespaces. Run this **before** Argo CD. This is not Terraform.

| Namespace object | Purpose |
| --- | --- |
| `argocd` | Where Argo CD pods go |
| `kong-ai-gateway` | Kong + Istio sidecar (`istio-injection: enabled`) |

## AWS login vs EKS

`aws sso login` / AWS keys talk to **AWS APIs**. Helm and kubectl talk to the **Kubernetes API** on the EKS endpoint. You need both: AWS creds, then kubeconfig.

```bash
aws eks update-kubeconfig --name kong-ai-dev --region us-east-2
kubectl get ns
./aws/helm/namespace/install.sh
```

`--namespace kube-system` on Helm is only where this **release Secret** is stored. The script still creates cluster objects named `argocd` and `kong-ai-gateway`. You cannot install this chart with `--namespace argocd` because that namespace does not exist yet.

Full connect / kubeconfig / console vs kubectl: **[CONNECT.md](CONNECT.md)**.
