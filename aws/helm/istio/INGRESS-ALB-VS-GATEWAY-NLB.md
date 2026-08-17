# Ingress + ALB vs Istio Gateway + NLB

This cluster uses **Istio Gateway + one internet NLB**. It does **not** use Kubernetes `Ingress` and does **not** use an ALB.

Default EKS: **no Ingress, no NLB, no ALB.** Apps are ClusterIP until you add a door.

---

## The two doors

### A — Kubernetes Ingress + AWS ALB

```text
Internet
    →  ALB  (L7 HTTP, host/path, often 80/443)
         →  AWS Load Balancer Controller watches kind: Ingress
              →  Kong / other pods
```

Needs: `kind: Ingress`, **AWS Load Balancer Controller**, usually ACM certs, target groups per service.

### B — Istio Gateway + AWS NLB (this repo)

```text
Internet
    →  NLB  (L4 TCP, many ports on one hostname)
         →  Service istio-ingressgateway  (LoadBalancer + nlb annotation)
              →  Envoy pod  (label istio: ingressgateway)
                   →  Gateway + VirtualService
                        →  ClusterIP Kong :8000 / Manager :8002 / Argo :8080
```

Needs: Istio (`istiod` + ingressgateway), Gateway/VS YAML. **No** Ingress objects.

---

## Side by side

| | Ingress + ALB | Istio Gateway + NLB (here) |
| --- | --- | --- |
| Kubernetes API | `networking.k8s.io/Ingress` | `networking.istio.io` Gateway + VirtualService |
| AWS LB | **ALB** (HTTP/HTTPS) | **NLB** (TCP) |
| Who creates the LB | AWS Load Balancer Controller | In-tree / cloud provider on `Service` `type: LoadBalancer` |
| HTTP routing | ALB rules (host, path) | Envoy: Gateway (listen) + VirtualService (route) |
| Extra ports (8001, 8002, 8080) | Awkward (HTTP-oriented) | Natural: more TCP listeners on the **same** NLB |
| TLS | ALB + ACM (very strong) | Istio Gateway TLS or pass-through |
| Mesh / mTLS to Kong | No (unless you add Istio anyway) | Sidecar + PeerAuthentication |
| Retries, timeouts, circuit break | Limited (ALB stickiness etc.) | DestinationRule / VS |
| One LB for Kong + Argo | Possible with paths/hosts | **Ports** on one NLB (`:80`, `:8080`, `:8002`) |
| Installed in this repo | **No** | **Yes** (`./aws/helm/istio/install.sh`) |
| Terraform | Often none (controller + Ingress) | NLB **not** in TF; Helm Service owns it |

---

## Why not both

Two internet load balancers = two bills, two DNS names, two health-check stories, two places to debug 502s.

```text
BAD:  Internet → ALB → Kong
              → NLB → Istio → Kong     (double hop, double cost)

HERE: Internet → NLB → Istio → Kong / Argo
```

If Istio already terminates the public TCP and does HTTP routing, **ALB has no job**. If you only wanted ALB path routing and no mesh, **Istio has no job**.

This platform needs **mesh** (sidecar on Kong, `istio-injection=enabled`) **and** a public URL. Istio’s ingressgateway is that URL. Adding Ingress+ALB would duplicate the door.

---

## Concrete: what the internet hits here

| URL | LB | Port | Istio | App |
| --- | --- | --- | --- | --- |
| `http://<NLB>/get` | NLB | 80 | Kong Gateway + VS | Kong proxy → httpbin |
| `http://<NLB>:8002` | same NLB | 8002 | Kong Gateway + VS | Manager |
| `http://<NLB>:8001` | same NLB | 8001 | Kong Gateway + VS | Admin API |
| `http://<NLB>:8080` | same NLB | 8080 | `aws/helm/argocd/istio.yaml` | Argo CD |

Kong Service stays **ClusterIP**. Only `istio-ingressgateway` is `LoadBalancer`.

With Ingress+ALB you would typically get `http://<ALB>/` on 80/443 and invent extra ALBs or Ingress rules for 8002/8080 — or put Argo on a path like `/argocd`. This repo avoided that by **ports on one NLB**.

---

## Where Istio is the better fit (this Kong platform)

Not “better at every AWS feature.” Better at **what this stack actually does**.

| Need | Ingress + ALB | Istio + NLB |
| --- | --- | --- |
| Public TCP door | ALB is HTTP-first | NLB is built for multi-port TCP |
| Kong + Manager + Argo on **one** hostname | Path hacks or extra ALBs | Ports 80 / 8002 / 8080 |
| L7 after the LB (plugins, `/get`) | Kong still needed | Kong still needed; Istio only delivers bytes to Kong |
| mTLS pod-to-pod | Not provided | Sidecar |
| Same routing API in-cluster and at the edge | Ingress ≠ mesh | Gateway/VS everywhere |
| Drop public URL, keep cluster | Delete Ingress (ALB $ stops) | `istio/uninstall.sh` (NLB $ stops); EKS stays |
| GitOps | Ingress YAML | Gateway/VS already in Kong Helm chart (Argo) |
| No second AWS controller | Must install LBC | Annotation on a Service |

Istio **ingress** is Envoy. Kong is still the **API gateway** (plugins, declarative `kong.yml`). They stack: NLB → Istio → Kong → httpbin.

---

## Where Ingress + ALB is actually stronger

Do not claim Istio wins every column.

| Need | Winner |
| --- | --- |
| Simplest HTTP website, no mesh | **Ingress + ALB** (or even one Service NLB) |
| AWS WAF, Shield, ACM cert on the LB | **ALB** (native) |
| Cheapest ops (no istiod, no sidecars) | **Ingress + ALB** |
| CPU on a small node (`t3.medium`) | **ALB** — Istio sidecar + istiod + ingressgateway cost RAM |
| Team only knows Ingress | **Ingress** |
| L4 non-HTTP (gRPC-raw, MQTT) | **NLB** (with or without Istio) |

If the app were a static site and you did not want a mesh, ALB+Ingress would be the smaller design. This repo is Kong + mesh + Argo on one DNS name → Istio+NLB.

---

## “Ingress” vs “Istio ingress gateway”

Easy mix-up:

| Phrase | Meaning |
| --- | --- |
| **Ingress** | Kubernetes resource `kind: Ingress` |
| **Istio ingress gateway** | The **Deployment/Service** named `istio-ingressgateway` (front-door Envoy) |
| **Istio Gateway** | CR that **configures** that Envoy (ports/hosts) |

`istio-ingressgateway` is **not** `kind: Ingress`. It is a LoadBalancer Service that happens to be named ingress.

---

## What we would tell architecture

> We do not install Ingress or an ALB. EKS does not ship a public app LB.  
> One **NLB** is created by Istio’s `LoadBalancer` Service.  
> **Gateway / VirtualService** tell Envoy where to send each port.  
> Kong remains ClusterIP; plugins never require an ALB.  
> A second ALB would only duplicate the internet hop and the bill.

Uninstall path stays: `./aws/helm/istio/uninstall.sh` removes the NLB; Terraform EKS is untouched.
