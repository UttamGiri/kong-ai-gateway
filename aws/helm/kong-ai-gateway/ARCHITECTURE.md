# Kong AI Gateway — image, Helm, Argo CD

Target flow. **Docker Registry (Docker Hub)**, not ECR. Namespace `kong-ai-gateway` already exists. Argo CD in `argocd` deploys this Helm chart.

**Base image:** Kong Gateway Enterprise (`kong/kong-gateway:3.9`). Dockerfile extends it and `COPY`s `aws/kong/plugins/custom-header`. Not Kong Konnect (no login dashboard in this image).

---

## Folders

```text
.github/workflows/docker-publish.yml
aws/kong/Dockerfile
aws/kong/plugins/custom-header/
aws/helm/kong-ai-gateway/          # this chart
aws/argocd/kong-ai-gateway.yaml    # Argo CD Application
```

The plugin lives **outside** this Helm chart. The Dockerfile copies it **into** the image. Helm only names the image (`values.yaml` `image.repository` + `image.tag`).

---

## 1. Build and ship the image

```mermaid
flowchart LR
    subgraph src ["Git develop"]
        BASE["FROM kong/kong-gateway:3.9<br/>Enterprise"]
        PLUG["aws/kong/plugins/<name><br/>custom plugin folder"]
        DF["aws/kong/Dockerfile"]
        BASE --> DF
        PLUG -->|"COPY into image"| DF
    end

    subgraph gha ["GitHub Action"]
        BUILD["docker build"]
        PUSH["docker push"]
        BUILD --> PUSH
    end

    subgraph reg ["Docker Registry"]
        IMG["docker.io/USER/kong-ai-gateway:git-sha"]
    end

    DF --> BUILD
    PUSH --> IMG
```

```mermaid
sequenceDiagram
    autonumber
    participant Dev as Developer
    participant GH as GitHub develop
    participant GHA as docker-publish.yml
    participant REG as Docker Registry
    participant Helm as aws/helm/kong-ai-gateway/values.yaml

    Dev->>GH: Dockerfile + plugin folder
    GH->>GHA: push / workflow_dispatch
    GHA->>GHA: docker build FROM kong/kong-gateway COPY plugin
    GHA->>REG: docker push user/kong-ai-gateway:sha
    Dev->>Helm: image.tag = sha
    Note over GHA,REG: Helm does not build the image. Nodes pull it.
```

---

## 2. Argo CD deploys the Helm chart

Argo CD does **not** build Docker images. It reads this chart and applies it to namespace **`kong-ai-gateway`**.

```mermaid
flowchart TB
    subgraph git ["Git"]
        CHART["Helm chart<br/>aws/helm/kong-ai-gateway"]
        VAL["values.yaml<br/>image.repository + tag"]
        APP["Argo CD Application<br/>destination ns: kong-ai-gateway"]
        CHART --> VAL
        VAL --> APP
    end

    subgraph ns1 ["namespace argocd"]
        ARGO["Argo CD"]
    end

    subgraph ns2 ["namespace kong-ai-gateway<br/>istio-injection=enabled"]
        DEPLOY["Deployment 1 replica"]
        SVC["Service ClusterIP :8000"]
        MESH["Istio Gateway / VS / DR / PA"]
        POD["Pod: Kong Enterprise + plugin<br/>+ Istio sidecar"]
        DEPLOY --> POD
        SVC --> POD
        MESH --> SVC
    end

    subgraph reg ["Docker Registry"]
        IMG["kong-ai-gateway:tag"]
    end

    APP -->|"sync"| ARGO
    ARGO -->|"helm template + apply"| ns2
    POD -->|"image pull"| IMG
```

Order already done vs next:

| Step | Status |
| --- | --- |
| Terraform EKS | done |
| Namespaces `argocd` + `kong-ai-gateway` | done |
| Argo CD install | done |
| Dockerfile `FROM kong/kong-gateway` + plugin COPY | done (`aws/kong`) |
| GitHub Action build/push | done (Actions → Docker publish Kong AI Gateway) |
| Argo CD Application for this chart | done (`aws/argocd/kong-ai-gateway.yaml`) |

---

## 3. What this Helm chart creates (when Argo syncs)

| Object | Notes |
| --- | --- |
| Deployment | 1 pod, image from Docker Registry |
| Service | ClusterIP port 8000 — **no NLB** (no extra AWS $) |
| ServiceAccount | |
| Istio Gateway, VirtualService, DestinationRule, PeerAuthentication | only if `istio.enabled` |

No `kind: Namespace` here. Namespace chart owns `kong-ai-gateway`.

---

## 4. ClusterIP, Ingress, ALB, NLB, Istio Gateway

EKS does **not** turn on Ingress by itself. If you add nothing, the Service stays **ClusterIP** (this chart). Nothing outside the cluster can call Kong.

| Piece | What it is | Reads HTTP Host/path? | This chart |
| --- | --- | --- | --- |
| **Service ClusterIP** | In-cluster VIP only | No | **On** (`service.type: ClusterIP`) |
| **Ingress** | Kubernetes YAML: host/path → Service | Yes (rules) | Not used |
| **ALB** | AWS Layer-7 load balancer | Yes | Not created |
| **NLB** | AWS Layer-4 load balancer (TCP) | No | **On** — Istio `istio-ingressgateway` Service |
| **Istio Gateway** | Config for Istio’s ingressgateway pods | Yes (with VirtualService) | **On** (`istio.enabled: true`, host `*`) |

**Ingress** is the wish. On EKS, **AWS Load Balancer Controller** reads Ingress and creates an **ALB**. Without that controller, Ingress YAML does nothing.

**NLB** usually skips Ingress: `Service type: LoadBalancer` → AWS NLB → Service → Pod.

```mermaid
flowchart TB
  subgraph today ["Today — this cluster"]
    PC["Laptop"]
    CIP["Service ClusterIP<br/>kong-ai-gateway :8000"]
    POD["Kong pod"]
    PC -.->|"not reachable from internet"| CIP
    CIP --> POD
  end
```

```mermaid
flowchart LR
  CLIENT["Client"]

  subgraph alb_path ["Ingress + ALB"]
    ING["kind: Ingress"]
    CTRL["AWS Load Balancer Controller"]
    ALB["AWS ALB HTTP/HTTPS"]
    ING --> CTRL --> ALB
  end

  subgraph nlb_path ["NLB only"]
    LBSVC["Service type LoadBalancer"]
    NLB["AWS NLB TCP"]
    LBSVC --> NLB
  end

  subgraph istio_path ["Istio — off in values.yaml"]
    GW["Istio Gateway CR"]
    VS["VirtualService"]
    IGW["istio-ingressgateway pod"]
    GW --> IGW
    VS --> IGW
  end

  SVC["Service ClusterIP"]
  POD2["Kong pod"]

  CLIENT --> ALB --> SVC
  CLIENT --> NLB --> SVC
  CLIENT --> IGW --> SVC
  SVC --> POD2
```

```mermaid
flowchart TB
  subgraph compare ["Same destination, different front door"]
    A["Ingress YAML"] -->|"controller creates"| B["ALB"]
    C["type: LoadBalancer"] -->|"AWS creates"| D["NLB"]
    E["Istio Gateway CR"] -->|"configures"| F["Istio ingress pod<br/>often still behind an NLB"]
    B --> S["Service kong-ai-gateway"]
    D --> S
    F --> S
    S --> P["Pod"]
  end
```

ServiceAccount is **not** on this path. It is pod identity, not how traffic enters.

---

## 5. Cost

| Piece | Extra AWS $ |
| --- | --- |
| Custom image in Docker Hub / registry | $0 on AWS (not ECR) |
| Kong pod on existing t3.medium | $0 extra if it fits |
| ClusterIP Service | $0 |
| LoadBalancer / NLB | Istio ingressgateway ≈ **$0.66/day** extra |
