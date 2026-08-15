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

Kong Manager (needs Admin API on the same host):

http://\<NLB_HOSTNAME\>:8002

| Port on NLB | Where it goes |
| --- | --- |
| 80 | Kong proxy |
| 8002 | Kong Manager UI |
| 8080 | Argo CD UI |

| Install | Namespace | Role |
| --- | --- | --- |
| `istio-base` + `istiod` | `istio-system` | Mesh control plane |
| `istio-ingressgateway` | `istio-ingress` | Front door pods; **NLB** on port 80 |

Kong chart Gateway selector is `istio: ingressgateway` — it binds to these pods.

## Uninstall

There is **no** custom NLB chart. The NLB is the `LoadBalancer` Service inside the official `istio/gateway` release.

```bash
./aws/helm/istio/uninstall.sh          # drops ingress + NLB (~$0.66/day stops)
./aws/helm/istio/uninstall.sh --all    # also istiod / CRDs / namespaces
```

Then set `istio.enabled: false` in `aws/helm/kong-ai-gateway/values.yaml` and push so Argo deletes Kong’s Gateway/VS. Kong and Argo CD **pods stay**; they just lose the public URL.
