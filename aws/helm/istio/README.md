# Istio (ingress NLB)

Installs **istiod** and **istio-ingressgateway**. The ingress Service is `type: LoadBalancer` with the AWS **NLB** annotation (not ALB).

**Extra AWS cost:** NLB + public IPv4 ≈ **$0.66/day**. ClusterIP Kong stays as-is; the NLB is only on the Istio ingress Service.

```bash
./aws/helm/istio/install.sh
```

Then set `istio.enabled: true` in `aws/helm/kong-ai-gateway/values.yaml` (Argo CD syncs Gateway + VirtualService). Restart Kong so the sidecar injects:

```bash
kubectl -n kong-ai-gateway rollout restart deploy/kong-ai-gateway
```

Public URL:

```bash
kubectl -n istio-ingress get svc istio-ingressgateway
curl -sS -D - http://<NLB_HOSTNAME>/get
```

| Install | Namespace | Role |
| --- | --- | --- |
| `istio-base` + `istiod` | `istio-system` | Mesh control plane |
| `istio-ingressgateway` | `istio-ingress` | Front door pods; **NLB** on port 80 |

Kong chart Gateway selector is `istio: ingressgateway` — it binds to these pods. VirtualService sends that HTTP to Service `kong-ai-gateway:8000`. Admin 8001 / Manager 8002 stay ClusterIP only.
