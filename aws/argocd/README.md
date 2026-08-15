# Argo CD Application for Kong AI Gateway

Applies [kong-ai-gateway.yaml](kong-ai-gateway.yaml): Argo CD syncs Helm chart `aws/helm/kong-ai-gateway` into namespace `kong-ai-gateway`.

**Order**

1. Image on Docker Hub — Actions → **Docker publish Kong AI Gateway**
2. Namespaces + Argo CD already installed
3. `./aws/argocd/install.sh`

Repo is public; Argo CD can git pull without a credential. Helm `image.repository` must match `DOCKERHUB_USERNAME` (default `docker.io/uttamgiri32/kong-ai-gateway`).

When `image.tag` changes, or a plugin is rebuilt into a new tag, Argo redeploys: **[GITOPS.md](GITOPS.md)**.
