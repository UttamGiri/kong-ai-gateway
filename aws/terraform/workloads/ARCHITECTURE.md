# AWS workloads architecture

Target layout for **kong-ai-gateway-aws-workload** (HCP Version control: plan on the workspace, Confirm & Apply). Image registry is a **Docker Registry** (Docker Hub or self-hosted `registry:2`), not ECR.

| Environment | Path | Contents |
| --- | --- | --- |
| **dev** | `dev/` | Terraform: VPC, one subnet, EKS only |
| **prod** | `prod/` | Empty on purpose |

Namespaces are **not** Terraform. They are a Helm chart (`aws/helm/namespace`) and they **do** appear on the cluster diagrams below.

---

## 1. Folder tree (repo)

```text
kong-ai-gateway/
├── .github/workflows/
│   └── docker-publish.yml
├── aws/
│   ├── helm/
│   │   ├── namespace/                 # TWO namespaces only
│   │   │   └── templates/
│   │   │       ├── argocd.yaml
│   │   │       └── kong-ai-gateway.yaml
│   │   └── kong-ai-gateway/           # app + mesh (not namespaces)
│   │       └── templates/
│   │           ├── deployment.yaml    # pods
│   │           ├── service.yaml
│   │           ├── serviceaccount.yaml
│   │           └── istio/
│   │               ├── gateway.yaml
│   │               ├── virtualservice.yaml
│   │               ├── destinationrule.yaml
│   │               └── peerauthentication.yaml
│   ├── argocd/
│   └── terraform/workloads/
│       ├── dev/                       # Terraform root: VPC + 1 subnet + EKS
│       │   ├── versions.tf
│       │   ├── providers.tf
│       │   └── variables.tf
│       └── prod/                      # empty
```

```mermaid
flowchart TB
    subgraph repo ["GitHub: UttamGiri/kong-ai-gateway  branch develop"]
        subgraph gha [".github/workflows"]
            DOCKER["docker-publish.yml later<br/>docker build + docker push"]
        end

        subgraph tf ["aws/terraform/workloads"]
            DEV["dev/<br/>VPC + 1 subnet + EKS"]
            PROD["prod/<br/>empty"]
        end

        subgraph helm ["aws/helm"]
            NSCHART["namespace/<br/>creates ns argocd<br/>creates ns kong-ai-gateway"]
            KONGCHART["kong-ai-gateway/<br/>pods, Service, Istio"]
        end
    end

    DEV -->|"git push develop"| HCP["HCP workspace<br/>kong-ai-gateway-aws-workload<br/>plan then Confirm and Apply"]
    HCP -->|"remote apply"| EKS["EKS — no namespaces yet"]
    NSCHART -->|"Helm"| NS1["namespace argocd"]
    NSCHART -->|"Helm"| NS2["namespace kong-ai-gateway<br/>istio-injection=enabled"]
    EKS --> NS1
    EKS --> NS2
    DOCKER -->|"docker push"| REG["Docker Registry"]
    KONGCHART -->|"image pull"| REG
    KONGCHART -->|"deploy into"| NS2
    NS1 --> ARGO["Argo CD"]
    ARGO -->|"sync Helm chart"| KONGCHART
```

---

## 2. What Terraform creates in `dev/`

```mermaid
flowchart LR
    subgraph workloads ["aws/terraform/workloads"]
        subgraph devbox ["dev/  — Terraform"]
            VPC["VPC"]
            SUB["One subnet<br/>single AZ — lab only"]
            EKS["EKS cluster"]
            VPC --> SUB --> EKS
        end

        subgraph prodbox ["prod/"]
            EMPTY["Empty"]
        end
    end
```

No registry, no namespaces, no Kong, no Argo CD in Terraform. Namespaces appear after the **namespace Helm chart** runs (next section).

---

## 3. Namespaces — Helm chart `aws/helm/namespace`

Namespaces **are** on the cluster. They are just not Terraform. Chart `aws/helm/namespace` creates both:

```mermaid
flowchart TB
    TF["Terraform<br/>VPC + subnet + EKS"] --> EKS["EKS<br/>empty of app namespaces"]

    NSCHART["Helm: aws/helm/namespace"]
    EKS --> NSCHART

    NSCHART --> NS1["namespace: argocd"]
    NSCHART --> NS2["namespace: kong-ai-gateway<br/>label istio-injection=enabled"]

    subgraph ns1box ["inside argocd"]
        ARGO["Argo CD<br/>official chart later"]
    end

    subgraph ns2box ["inside kong-ai-gateway"]
        DEPLOY["Deployment / pods"]
        SVC["Service"]
        MESH["Istio: Gateway<br/>VirtualService<br/>DestinationRule<br/>PeerAuthentication"]
    end

    NS1 --> ARGO
    NS2 --> DEPLOY
    NS2 --> SVC
    NS2 --> MESH
    ARGO -->|"syncs aws/helm/kong-ai-gateway"| ns2box
```

| Chart | Path | Creates |
| --- | --- | --- |
| **namespace** | `aws/helm/namespace` | `argocd` + `kong-ai-gateway` only |
| **kong-ai-gateway** | `aws/helm/kong-ai-gateway` | pods, Service, ServiceAccount, Istio mesh objects **in** `kong-ai-gateway` |

Do not put `kind: Namespace` inside the Kong chart. Keep namespaces in `helm/namespace` so mesh labels (`istio-injection`) are not tied to app rollouts.

**Order**

1. Terraform: VPC → subnet → EKS  
2. Helm `aws/helm/namespace`: both namespaces  
3. Helm Argo CD into `argocd`  
4. Argo CD syncs `aws/helm/kong-ai-gateway` into `kong-ai-gateway` (pods, services, Istio)

---

## 4. Docker Registry → Helm → Argo CD → Kong

Not ECR. **`docker build` / `docker push`** to a Docker Registry, then Helm `image.repository` points at that registry. Nodes **pull** the image when Argo CD syncs.

Examples of registry URL (pick one later):

- Docker Hub: `docker.io/<user>/kong-ai-gateway:<tag>`
- Self-hosted: `registry.example.com/kong-ai-gateway:<tag>` (Docker Registry `registry:2`)

```mermaid
sequenceDiagram
    autonumber
    participant Dev as Developer
    participant GH as GitHub develop
    participant GHA as GitHub Action docker-publish
    participant REG as Docker Registry
    participant Argo as Argo CD ns/argocd
    participant Helm as Helm chart aws/helm/kong-ai-gateway
    participant Kong as Pods in ns/kong-ai-gateway

    Dev->>GH: Push Dockerfile / chart
    GH->>GHA: docker build
    GHA->>GHA: docker build -t user/kong-ai-gateway:git-sha
    GHA->>REG: docker push user/kong-ai-gateway:git-sha
    Note over GHA,REG: Docker Registry stores the image. Helm does not build it.

    Dev->>GH: values.yaml image.tag = git-sha
    Argo->>GH: Git poll / webhook
    Argo->>Helm: helm pull / render chart
    Argo->>Kong: CreateNamespace + apply workload
    Kong->>REG: docker/containerd pull image
```

```mermaid
flowchart LR
    subgraph ci ["GitHub Action"]
        BUILD["docker build"]
        PUSH["docker push"]
        BUILD --> PUSH
    end

    subgraph registry ["Docker Registry"]
        IMG["user/kong-ai-gateway:tag"]
    end

    subgraph gitops ["Git"]
        CHART["Helm values<br/>image.repository = docker.io/user/kong-ai-gateway"]
        APP["Argo CD Application<br/>CreateNamespace=true<br/>destination: kong-ai-gateway"]
    end

    subgraph cluster ["EKS"]
        PULL["kubelet pull"]
        RUN["Kong pods"]
    end

    PUSH --> IMG
    IMG --> CHART
    CHART --> APP
    APP --> PULL
    IMG --> PULL
    PULL --> RUN
```

Cluster nodes need pull access (public Hub repo, or `imagePullSecret` for a private Docker Registry). Terraform does not create that registry.

---

## 5. End-to-end: who owns what

```mermaid
flowchart TB
    subgraph platform ["Terraform — AWS"]
        VPC["VPC"]
        SUB["1 subnet"]
        EKS["EKS"]
        VPC --> SUB --> EKS
    end

    subgraph gitops2 ["Helm — Kubernetes"]
        NS["helm/namespace<br/>ns argocd + ns kong-ai-gateway"]
        ARGO["Argo CD in ns argocd"]
        KONG["helm/kong-ai-gateway<br/>pods + Service + Istio"]
        NS --> ARGO
        NS --> KONG
        ARGO --> KONG
    end

    subgraph images ["Docker"]
        REG["Docker Registry"]
        REG --> KONG
    end

    EKS --> ARGO
```

| Layer | Tool | Creates |
| --- | --- | --- |
| IAM for HCP | Bootstrap Terraform | OIDC + role |
| Network + cluster | Workloads Terraform `dev/` | VPC, 1 subnet, EKS |
| Both namespaces | Helm `aws/helm/namespace` | `argocd`, `kong-ai-gateway` |
| Argo CD | Helm (official chart) into `argocd` | Argo CD |
| Kong image | `docker build` + `docker push` | Docker Registry |
| Kong + Istio | Helm `aws/helm/kong-ai-gateway` via Argo CD | Deployment, Service, Istio |
| Prod | Nothing | `prod/` empty |

---

## 6. Network sketch (dev, one subnet)

```mermaid
flowchart TB
    IGW["Internet Gateway"]

    subgraph vpc ["VPC  10.20.0.0/16  — dev"]
        subgraph az ["One AZ e.g. us-east-2a"]
            SUB["Subnet 10.20.1.0/24"]
            subgraph eks ["EKS"]
                N1["nodes"]
            end
            SUB --> N1
        end
    end

    IGW --> SUB
    N1 --> NS1["namespace argocd"]
    N1 --> NS2["namespace kong-ai-gateway"]
    NS1 --> ARGO["Argo CD"]
    NS2 --> PODS["pods + Service"]
    NS2 --> ISTIO["Istio sidecar + Gateway / VS"]
```

---

## 7. How a Kong change goes live

```mermaid
flowchart LR
    A["1. docker build"] --> B["2. docker push registry"]
    B --> C["3. Helm values image.tag"]
    C --> D["4. git push develop"]
    D --> E["5. Argo CD sync"]
    E --> F["6. Helm render + pull image"]
    F --> G["7. Rollout in kong-ai-gateway"]
```

No Terraform in this path.

---

## 8. Daily cost

Full calculator (rates, formulas, worked example, add-ons): **[dev/DESTROY.md](dev/DESTROY.md#cost-calculator-us-east-2-on-demand-linux-list-price)**.

This Terraform only (**1 × t3.medium**, no NAT, no NLB): **~$3.57/day** (~$107/month). `enabled = false` + apply → **$0/day** for this stack.

### Destroy switch (`enabled`)

All demo resources are behind `module.demo` with `count = var.enabled ? 1 : 0`. Set **`enabled = false`** and **apply** to destroy the stack. Do not comment out code.

| `enabled` | Result |
| --- | --- |
| `true` | Create / keep VPC, EKS, nodes |
| `false` | Hard delete (EBS `delete_on_termination`, no KMS, no S3 retain) |

HCP: set `enabled = false`, Start new run, Confirm & Apply. Helm/Istio load balancers are not in state; destroy tries to delete tagged ELBs first so the VPC can go.

Larger nodes (`t3.large` × 2) add ~$2/day. Turning the cluster off nights/weekends is the main way to cut this (EKS control plane still bills if the cluster exists).

These are list prices, not a quote. Check [AWS Pricing](https://aws.amazon.com/eks/pricing/) and the billing console after apply.

---

## 9. HCP / GitHub

- Workspace **kong-ai-gateway-aws-workload**: **Version control**. Branch **`develop`**. Working directory **`aws/terraform/workloads/dev`**. Trigger prefix `aws/terraform/workloads`. Auto-apply off.
- Push matching files → plan appears on the HCP workspace → **Confirm & Apply**.
- Bootstrap: same VCS pattern on `aws/terraform/bootstrap`.
