# How Terraform connects to AWS

This file is the connection model only: who authenticates, what AWS trusts, and how credentials are minted. Operator steps live in [hcp-terraform-aws-bootstrap.md](./hcp-terraform-aws-bootstrap.md). Official AWS OIDC docs: [Dynamic credentials with the AWS provider](https://developer.hashicorp.com/terraform/cloud-docs/dynamic-provider-credentials/aws-configuration).

There are **two Terraform-to-AWS paths**. They never share the same credentials.

| Path | Who runs Terraform | How AWS is authenticated |
| --- | --- | --- |
| Bootstrap (first apply) | Your laptop (Cursor) | Your IAM Identity Center session or IAM user keys |
| Workloads (every later run) | [HCP Terraform](https://app.terraform.io/) workers | OIDC → IAM role `hcp-terraform-run` → STS |

---

## What `aws/terraform/bootstrap` creates

One local `terraform apply` creates **trust objects only**. It does not create VPC, EKS, Helm, or Kong.

```mermaid
flowchart TB
    Apply["terraform apply<br/>aws/terraform/bootstrap<br/>runs on your laptop"]

    subgraph aws [Created in AWS — account 499689292506]
        IdP["IAM OIDC identity provider<br/>url: https://app.terraform.io<br/>audience: aws.workload.identity"]
        Role["IAM role<br/>hcp-terraform-run"]
        Trust["Trust policy on the role<br/>AssumeRoleWithWebIdentity<br/>locked to org + two workspaces"]
        Attach["Policy attachment<br/>AdministratorAccess"]
        IdP --> Role
        Role --> Trust
        Role --> Attach
    end

    subgraph hcp [Created on app.terraform.io]
        Proj["Project<br/>kong-ai-gateway"]
        WsB["Workspace<br/>kong-ai-gateway-aws-bootstrap"]
        WsW["Workspace<br/>kong-ai-gateway-aws"]
        Vars["Env vars on both workspaces<br/>TFC_AWS_PROVIDER_AUTH=true<br/>TFC_AWS_RUN_ROLE_ARN<br/>AWS_REGION"]
        Proj --> WsB
        Proj --> WsW
        WsB --> Vars
        WsW --> Vars
    end

    subgraph disk [Created on this laptop]
        State["terraform.tfstate<br/>local file — not remote yet"]
    end

    Apply --> IdP
    Apply --> Role
    Apply --> Proj
    Apply --> State
```

### AWS

| Resource | Default name | File |
| --- | --- | --- |
| OIDC provider | issuer `https://app.terraform.io` | `bootstrap/aws_oidc.tf` |
| IAM role | `hcp-terraform-run` | `bootstrap/aws_oidc.tf` |
| Trust policy | `sub` for bootstrap + workloads workspaces | `bootstrap/aws_oidc.tf` |
| Role policy | `arn:aws:iam::aws:policy/AdministratorAccess` | `bootstrap/aws_oidc.tf` |

### HCP Terraform

Needs `terraform login` / `TFE_TOKEN`. Organization is **not** created unless `create_tfc_organization = true`.

| Resource | Default name | File |
| --- | --- | --- |
| Project | `kong-ai-gateway` | `bootstrap/tfc.tf` |
| Workspace | `kong-ai-gateway-aws-bootstrap` | `bootstrap/tfc.tf` |
| Workspace | `kong-ai-gateway-aws` | `bootstrap/tfc.tf` |
| Env var | `TFC_AWS_PROVIDER_AUTH=true` | `bootstrap/tfc.tf` |
| Env var | `TFC_AWS_RUN_ROLE_ARN` = role ARN | `bootstrap/tfc.tf` |
| Env var | `AWS_REGION` | `bootstrap/tfc.tf` |

### Not created

- VPC, subnets, EKS, load balancers
- Helm releases, Kong Gateway
- AWS account, IAM Identity Center user, root keys
- Remote state on HCP Terraform for bootstrap (that is a later migrate)

Workload infra is created later by workspace `kong-ai-gateway-aws` from `aws/terraform/workloads`.

---

## Credentials vs role (GCP SA + WIF mapped to AWS)

Full write-up: [gcp-sa-wif-vs-aws-oidc.md](./gcp-sa-wif-vs-aws-oidc.md).

Two identities. They are not the same.

| | GCP | AWS here |
| --- | --- | --- |
| **You / bootstrap** | Your Google user (ADC) or a bootstrap SA JSON key | IAM user **access key + secret**, or Identity Center role `AWSAdministratorAccess` |
| **What Terraform Cloud becomes** | Workload SA + WIF (no JSON key in TFC) | IAM role `hcp-terraform-run` + OIDC (no `AKIA` key in TFC) |

The access key does **not** assume `hcp-terraform-run` during bootstrap. That key *is* an IAM user. Terraform talks to IAM **as that user** and **creates** the role. Later, HCP Terraform **assumes** the role with an OIDC token — that is WIF.

```mermaid
flowchart TB
    subgraph gcp [GCP]
        GUser["Your user / bootstrap SA key"]
        GWIF["WIF pool + OIDC provider<br/>trusts app.terraform.io"]
        GSA["Terraform service account"]
        GBind["workloadIdentityUser<br/>who may impersonate the SA"]
        GRoles["SA IAM roles<br/>e.g. editor — what TFC may create"]
        GUser -->|"creates"| GWIF
        GUser -->|"creates"| GSA
        GUser -->|"creates"| GBind
        GSA --> GRoles
    end

    subgraph aws [AWS]
        AUser["IAM user access key+secret<br/>or SSO AWSAdministratorAccess"]
        AIdP["IAM OIDC provider<br/>trusts app.terraform.io"]
        ARole["IAM role hcp-terraform-run"]
        ATrust["Trust policy<br/>who may AssumeRoleWithWebIdentity"]
        APerms["Role policies<br/>AdministratorAccess — what TFC may create"]
        AUser -->|"creates"| AIdP
        AUser -->|"creates"| ARole
        AUser -->|"creates"| ATrust
        ARole --> APerms
    end
```

### Identity 1 — the access key / SSO user (bootstrap only)

This principal **does not assume** `hcp-terraform-run`. It needs permission to **create IAM trust objects**.

If you use Identity Center, you already assume permission set `AWSAdministratorAccess`. That is enough.

If you use an IAM user key (`AKIA…`), that **user** must have IAM admin (we used `AdministratorAccess` on `bootstrap-admin`).

With those permissions, this local apply can create:

| Create | Why |
| --- | --- |
| `iam:CreateOpenIDConnectProvider` | OIDC provider for `app.terraform.io` |
| `iam:CreateRole` | Role `hcp-terraform-run` |
| `iam:UpdateAssumeRolePolicy` | Trust policy (WIF binding) |
| `iam:AttachRolePolicy` | Attach `AdministratorAccess` to the run role |
| `iam:GetRole`, `iam:List*`, `iam:TagRole`, … | Read/update during apply |

It does **not** need to create VPC/EKS on this first apply. `AdministratorAccess` on the **user** could, but `bootstrap/` Terraform does not.

### Identity 2 — role `hcp-terraform-run` (HCP Terraform, like the GCP SA)

HCP Terraform never uses your access key. It presents an OIDC token; STS returns temporary `ASIA…` keys **for this role**.

| GCP | AWS |
| --- | --- |
| WIF provider trusts TFC issuer | OIDC provider `https://app.terraform.io` |
| `roles/iam.workloadIdentityUser` on the SA | Role **trust policy** `AssumeRoleWithWebIdentity` + `aud`/`sub` |
| SA email in `TFC_GCP_RUN_SERVICE_ACCOUNT_EMAIL` | Role ARN in `TFC_AWS_RUN_ROLE_ARN` |
| Roles on the SA (compute, container, …) | Policies **on the role** (`AdministratorAccess` today) |

What **this role** can create later (workloads): anything `AdministratorAccess` allows — VPC, EKS, IAM, etc. Tighten that policy after the platform exists.

```mermaid
flowchart LR
    subgraph bootstrap [Laptop — identity 1]
        Key["Access key + secret<br/>IAM user bootstrap-admin<br/>OR SSO AdministratorAccess"]
        Key -->|"iam:CreateRole etc."| Create["Creates IdP + role"]
    end

    subgraph later [HCP Terraform — identity 2]
        TFC["Workspace run"]
        TFC -->|"OIDC token"| STS["STS AssumeRoleWithWebIdentity"]
        STS --> RunRole["hcp-terraform-run"]
        RunRole -->|"AdministratorAccess"| Infra["VPC EKS Kong …"]
    end

    Create --> RunRole
```

**Short version:** the key’s user is the *bootstrap admin* (creates WIF + SA). The role is the *workload identity* (TFC impersonates it). Do not put the key in HCP Terraform.

---

## 1. Two callers, two identities

```mermaid
flowchart TB
    subgraph laptop [Path A — first bootstrap]
        You["You in Cursor"]
        LocalTF["terraform apply<br/>aws/terraform/bootstrap<br/>backend = local"]
        HumanCreds["Your AWS identity<br/>Identity Center SSO<br/>or IAM user access key"]
        You --> LocalTF --> HumanCreds
    end

    subgraph tfc [Path B — later runs]
        Ws["HCP Terraform workspace"]
        OIDCTok["OIDC workload identity token"]
        Role["IAM role hcp-terraform-run"]
        STS["AWS STS temporary keys"]
        Ws --> OIDCTok --> Role --> STS
    end

    subgraph aws [AWS account VAFLT-DEV-ENV 499689292506]
        IAM["IAM APIs"]
        APIs["VPC / EKS / Kong / …"]
    end

    HumanCreds -->|"creates OIDC IdP + role"| IAM
    STS -->|"creates workloads"| APIs
```

Path A is allowed to use a long-lived key **only on the laptop**, and only to create the trust. Path B must not store `AKIA` keys in the workspace. Path B is OIDC, the AWS equivalent of a GCP service account plus WIF.

---

## 2. What “connect” means in AWS terms

HCP Terraform is outside AWS. AWS will not accept calls from it until three objects exist in **your** account:

```mermaid
flowchart LR
    subgraph trust [Trust layer — created by bootstrap]
        IdP["IAM OIDC provider<br/>url = https://app.terraform.io<br/>aud = aws.workload.identity"]
        Role["IAM role<br/>hcp-terraform-run"]
        TrustPol["Trust policy<br/>sts:AssumeRoleWithWebIdentity<br/>aud + sub conditions"]
        Perms["Permissions<br/>AdministratorAccess for now"]
        IdP --> Role
        Role --> TrustPol
        Role --> Perms
    end

    subgraph tfcvars [Told to HCP Terraform]
        V1["TFC_AWS_PROVIDER_AUTH = true"]
        V2["TFC_AWS_RUN_ROLE_ARN = role ARN"]
        V3["AWS_REGION"]
    end

    Role -.->|"ARN copied into workspace"| V2
```

| AWS object | Job |
| --- | --- |
| OIDC provider | “I trust tokens issued by `app.terraform.io`.” |
| IAM role | Identity HCP Terraform becomes for the length of a run. |
| Trust policy | Only *this* org / project / workspace may assume the role. |
| Permissions policy | What that identity is allowed to create in AWS. |
| Workspace env vars | Tell the run to use OIDC and which role ARN to assume. |

No static AWS key is stored in HCP Terraform after this.

---

## 3. First apply — laptop talks to AWS directly

Execution is local. State is local (`terraform.tfstate`). HCP Terraform workers do **not** call AWS yet.

```mermaid
sequenceDiagram
    autonumber
    actor You as Cursor terminal
    participant TF as Terraform CLI<br/>aws/terraform/bootstrap
    participant AWS as AWS IAM
    participant TFC as HCP Terraform API<br/>app.terraform.io

    You->>You: AWS creds in env or SSO<br/>must be account 499689292506
    You->>TF: terraform apply
    TF->>AWS: Create OIDC provider<br/>https://app.terraform.io
    TF->>AWS: Create role hcp-terraform-run
    TF->>AWS: Trust: aud + sub for two workspaces
    TF->>AWS: Attach AdministratorAccess
    Note over TF,TFC: tfe provider needs terraform login / TFE_TOKEN
    TF->>TFC: Create project kong-ai-gateway
    TF->>TFC: Create workspaces bootstrap + workloads
    TF->>TFC: Set TFC_AWS_PROVIDER_AUTH and TFC_AWS_RUN_ROLE_ARN
    TF->>You: Write terraform.tfstate on disk
```

Credentials on this path: **yours**. Terraform AWS provider uses the default chain (env vars, then profile). That is why `aws sts get-caller-identity` must show `499689292506` before apply.

---

## 4. After bootstrap — HCP Terraform talks to AWS via OIDC

A later `terraform apply` for `aws/terraform/workloads` is CLI-driven: Cursor uploads config; **HCP Terraform executes** the plan/apply. The AWS provider inside that run has no access key. HCP Terraform mints an OIDC token and AWS STS exchanges it for one-hour creds.

```mermaid
sequenceDiagram
    autonumber
    actor You as Cursor
    participant TFC as HCP Terraform workspace<br/>kong-ai-gateway-aws
    participant IdP as IAM OIDC provider<br/>app.terraform.io
    participant STS as AWS STS
    participant Role as IAM role<br/>hcp-terraform-run
    participant API as AWS APIs

    You->>TFC: terraform apply (CLI-driven)
    TFC->>TFC: Read TFC_AWS_PROVIDER_AUTH=true
    TFC->>TFC: Read TFC_AWS_RUN_ROLE_ARN
    TFC->>TFC: Mint OIDC token<br/>iss=https://app.terraform.io<br/>aud=aws.workload.identity<br/>sub=organization:ORG:project:kong-ai-gateway:workspace:kong-ai-gateway-aws:run_phase:plan
    TFC->>STS: AssumeRoleWithWebIdentity<br/>RoleArn + token
    STS->>IdP: Verify issuer, thumbprint, signature
    STS->>Role: Match aud and sub against trust policy
    Role-->>STS: Allow
    STS-->>TFC: AccessKeyId ASIA… + Secret + SessionToken<br/>ttl ~ 1 hour
    TFC->>API: Create / update infrastructure
    TFC->>TFC: Store workload state in HCP Terraform
```

`AKIA…` keys are long-lived IAM user keys. `ASIA…` keys are STS session keys. Path B only ever uses `ASIA…`.

---

## 5. Token claims the trust policy checks

AWS will not assume `hcp-terraform-run` for a random HCP Terraform org. The role trust policy requires:

```mermaid
flowchart TB
    Token["OIDC token from HCP Terraform"]
    Token --> Aud["aud == aws.workload.identity"]
    Token --> Sub["sub matches<br/>organization:ORG<br/>project:kong-ai-gateway<br/>workspace:NAME<br/>run_phase:plan or apply"]

    Aud --> OK{"both true?"}
    Sub --> OK
    OK -->|yes| Assume["sts:AssumeRoleWithWebIdentity"]
    OK -->|no| Deny["AccessDenied"]
```

Workspaces allowed by `aws_oidc.tf`:

```text
organization:<tfc_organization_name>:project:kong-ai-gateway:workspace:kong-ai-gateway-aws-bootstrap:run_phase:*
organization:<tfc_organization_name>:project:kong-ai-gateway:workspace:kong-ai-gateway-aws:run_phase:*
```

If `tfc_organization_name` in tfvars does not match the real HCP org, later remote runs fail assume-role even though bootstrap succeeded.

---

## 6. End-to-end after both paths exist

```mermaid
flowchart TB
    subgraph cursor [Cursor IDE]
        Apply1["1. terraform apply bootstrap<br/>runs here"]
        Apply2["2. terraform apply workloads<br/>CLI-driven trigger only"]
    end

    subgraph hcp [app.terraform.io]
        BootWS["workspace kong-ai-gateway-aws-bootstrap<br/>state moved here later"]
        WorkWS["workspace kong-ai-gateway-aws<br/>workload state from first workloads apply"]
        Vars["env: TFC_AWS_PROVIDER_AUTH<br/>TFC_AWS_RUN_ROLE_ARN"]
        WorkWS --- Vars
    end

    subgraph aws [AWS]
        IdP["OIDC provider app.terraform.io"]
        Role["role hcp-terraform-run"]
        Infra["workloads"]
        IdP --> Role --> Infra
    end

    Apply1 -->|"your AWS creds"| IdP
    Apply1 -->|"your AWS creds"| Role
    Apply1 -->|"tfe provider"| BootWS
    Apply1 -->|"tfe provider"| WorkWS
    Apply2 --> WorkWS
    WorkWS -->|"OIDC token"| IdP
    Role -->|"STS ASIA keys"| WorkWS
```

---

## 7. What is *not* a connection

| Thing | Connects Terraform to AWS? |
| --- | --- |
| HCP Terraform org / workspace alone | No. That is only control plane + state. |
| `TFE_TOKEN` / `terraform login` | No. That authenticates you *to HCP Terraform*, not to AWS. |
| Root access key | Must not be used. |
| IAM user key in a workspace variable | Works, but that is a static key in TFC. This repo uses OIDC instead. |
| Identity Center user | Authenticates **you** for Path A. TFC cannot log in as that user. |

---

## 8. Mapping if you know GCP

Full comparison: [gcp-sa-wif-vs-aws-oidc.md](./gcp-sa-wif-vs-aws-oidc.md).

| GCP | AWS in this repo |
| --- | --- |
| Service account | IAM role `hcp-terraform-run` |
| Workload Identity Federation | IAM OIDC provider + trust policy |
| SA JSON key | IAM access key (`AKIA`) — laptop bootstrap only |
| `TFC_GCP_RUN_SERVICE_ACCOUNT_EMAIL` | `TFC_AWS_RUN_ROLE_ARN` |
| `TFC_GCP_PROVIDER_AUTH=true` | `TFC_AWS_PROVIDER_AUTH=true` |
