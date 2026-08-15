# Kong AI Gateway — image, Helm, Argo CD

Target flow. **Docker Registry (Docker Hub)**, not ECR. Namespace `kong-ai-gateway` already exists. Argo CD in `argocd` deploys this Helm chart.

**Free image:** Kong Gateway OSS (`kong:3.9`). Dockerfile extends it and `COPY`s `aws/kong/plugins/custom-header`.

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
        BASE["FROM kong:OSS<br/>free Kong Gateway"]
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
    GHA->>GHA: docker build FROM kong OSS COPY plugin
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
        POD["Pod: Kong OSS + plugin<br/>+ Istio sidecar"]
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
| Dockerfile `FROM kong` + plugin COPY | done (`aws/kong`) |
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

## Cost

| Piece | Extra AWS $ |
| --- | --- |
| Custom image in Docker Hub / registry | $0 on AWS (not ECR) |
| Kong pod on existing t3.medium | $0 extra if it fits |
| ClusterIP Service | $0 |
| LoadBalancer / NLB | **do not enable** (~$0.66/day) |
