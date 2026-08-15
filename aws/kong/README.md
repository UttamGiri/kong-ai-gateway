# Kong AI Gateway image (OSS + custom plugin)

**Free base:** Docker Hub `kong:3.9` (Kong Gateway OSS). Not Enterprise.

The plugin is **not** inside the Helm chart. It lives in `plugins/custom-header/`. The Dockerfile copies it into the image.

```text
aws/kong/
├── Dockerfile                 # FROM kong:3.9 + COPY plugin
├── kong.yml                   # DB-less config (plugin enabled)
└── plugins/custom-header/     # injected at build time
    ├── handler.lua
    └── schema.lua
```

Build locally (optional):

```bash
docker build -t kong-ai-gateway:local aws/kong
```

Ship from GitHub: **Actions → Docker publish Kong AI Gateway → Run workflow**.

Secrets (repo): `DOCKERHUB_USERNAME`, `DOCKERHUB_TOKEN`. Image: `docker.io/<user>/kong-ai-gateway:<tag>`.
