# Namespace Helm chart

Creates the two cluster namespaces. This is not Terraform.

| Namespace | Purpose |
| --- | --- |
| `argocd` | Argo CD |
| `kong-ai-gateway` | Kong AI Gateway + Istio sidecar (`istio-injection: enabled`) |

Install after EKS exists, before Argo CD and Kong charts.
