# Kong AI Gateway Helm chart

Deploys into namespace `kong-ai-gateway` (created by `aws/helm/namespace`). Image is Kong OSS + `custom-header` plugin, pushed by **Docker publish Kong AI Gateway**.

**Deploy order**

1. Repo secrets `DOCKERHUB_USERNAME` and `DOCKERHUB_TOKEN`
2. Actions → **Docker publish Kong AI Gateway** → Run workflow from `develop`. No tag to type: the job increments `image.tag` by 1 and commits it.
3. Helm image is `docker.io/uttamgiri32/kong-ai-gateway` (Docker Hub user **uttamgiri32**). Secret `DOCKERHUB_USERNAME` must be the same.
4. `./aws/argocd/install.sh` — Argo CD syncs this chart

Istio is **off** (`istio.enabled: false`) until an Istio install exists. Service is ClusterIP (no NLB).

Kong Manager (OSS GUI) is not on the public internet. From this PC:

```bash
kubectl -n kong-ai-gateway port-forward svc/kong-ai-gateway 8001:8001 8002:8002
```

Open **http://localhost:8002**. Admin API is **http://localhost:8001**. DB-less mode is read-only in the UI.

| Path | What |
| --- | --- |
| `templates/deployment.yaml` | Pods |
| `templates/service.yaml` | ClusterIP Service |
| `templates/serviceaccount.yaml` | ServiceAccount |
| `templates/istio/` | Gateway, VirtualService, DestinationRule, PeerAuthentication |

Image comes from a **Docker Registry** (`docker build` / `docker push`), not ECR. Namespace label `istio-injection: enabled` injects the Istio sidecar into these pods.

Build → registry → Argo CD: **[ARCHITECTURE.md](ARCHITECTURE.md)**.
