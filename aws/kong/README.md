# Kong AI Gateway image (Enterprise + custom plugin)

**Base:** Docker Hub `kong/kong-gateway:3.9` (Kong Gateway Enterprise). Not OSS `kong:3.9`. Not Kong Konnect.

This is the **proxy image**. The Konnect login dashboard is still a Kong website, not this container. Enterprise features that need a license stay limited until you set `KONG_LICENSE_DATA` (Konnect trial or paid).

Kong Manager GUI listens on **8002** (read-only in DB-less). Proxy **8000**, Admin API **8001**.

The plugin is **not** inside the Helm chart. It lives in `plugins/custom-header/`. The Dockerfile copies it into the image.

```text
aws/kong/
├── Dockerfile                 # FROM kong/kong-gateway:3.9 + COPY plugin
├── kong.yml                   # DB-less config (plugin enabled)
└── plugins/custom-header/     # injected at build time
    ├── handler.lua
    └── schema.lua
```

Build locally (optional):

```bash
docker build -t kong-ai-gateway:local aws/kong
```

End-to-end pipeline (login, Action, Docker Hub, Helm, Argo CD): **[PIPELINE.md](PIPELINE.md)**.
