# Kong AI Gateway image (Enterprise + custom plugin)

**Base:** Docker Hub `kong/kong-gateway:3.9` (Kong Gateway Enterprise). Not OSS `kong:3.9`. Not Kong Konnect.

This is the **proxy image**. The Konnect login dashboard is still a Kong website, not this container. Enterprise features that need a license stay limited until you set `KONG_LICENSE_DATA` (Konnect trial or paid).

Kong Manager GUI listens on **8002** (read-only in DB-less). Proxy **8000**, Admin API **8001**.

Plugins are **not** inside the Helm chart. They live in `plugins/`. The Dockerfile copies them into the image.

```text
aws/kong/
├── Dockerfile                 # FROM kong/kong-gateway:3.9 + COPY plugins
├── kong.yml                   # DB-less config (plugins enabled)
└── plugins/
    ├── custom-header/         # X-Kong-AI-Gateway
    └── custom-request-id/     # X-Request-Id
```

Build locally (optional):

```bash
docker build -t kong-ai-gateway:local aws/kong
```

End-to-end pipeline (login, Action, Docker Hub, Helm, Argo CD): **[PIPELINE.md](PIPELINE.md)**.

Call Vertex Gemini from this Kong pod:

- Lab (GCP SA JSON key in a Secret): **[VERTEX-JSON-KEY.md](VERTEX-JSON-KEY.md)**
- Better (AWS IRSA + GCP WIF, no JSON key): **[VERTEX-WIF.md](VERTEX-WIF.md)**
- GCP paste + how the pod uses it + Terraform IRSA: **[VERTEX-GCP-PROVIDED.md](VERTEX-GCP-PROVIDED.md)**
