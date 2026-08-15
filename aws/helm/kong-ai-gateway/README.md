# Kong AI Gateway Helm chart

Deploys into namespace `kong-ai-gateway` (created by `aws/helm/namespace`). Image is Kong OSS + `custom-header` plugin, pushed by **Docker publish Kong AI Gateway**.

**Deploy order**

1. Repo secrets `DOCKERHUB_USERNAME` and `DOCKERHUB_TOKEN`
2. Actions → **Docker publish Kong AI Gateway** → tag `latest` (workflow from `develop`)
3. Set `image.repository` in `values.yaml` to `docker.io/<that-username>/kong-ai-gateway` if it is not `uttamgiri`
4. `./aws/argocd/install.sh` — Argo CD syncs this chart

Istio is **off** (`istio.enabled: false`) until an Istio install exists. Service is ClusterIP (no NLB).

| Path | What |
| --- | --- |
| `templates/deployment.yaml` | Pods |
| `templates/service.yaml` | ClusterIP Service |
| `templates/serviceaccount.yaml` | ServiceAccount |
| `templates/istio/` | Gateway, VirtualService, DestinationRule, PeerAuthentication |

Image comes from a **Docker Registry** (`docker build` / `docker push`), not ECR. Namespace label `istio-injection: enabled` injects the Istio sidecar into these pods.

Build → registry → Argo CD: **[ARCHITECTURE.md](ARCHITECTURE.md)**.
