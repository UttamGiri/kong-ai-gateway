# Kong AI Gateway Helm chart

Deploys into namespace `kong-ai-gateway` (created by `aws/helm/namespace`).

| Path | What |
| --- | --- |
| `templates/deployment.yaml` | Pods |
| `templates/service.yaml` | ClusterIP Service |
| `templates/serviceaccount.yaml` | ServiceAccount |
| `templates/istio/` | Gateway, VirtualService, DestinationRule, PeerAuthentication |

Image comes from a **Docker Registry** (`docker build` / `docker push`), not ECR. Namespace label `istio-injection: enabled` injects the Istio sidecar into these pods.
