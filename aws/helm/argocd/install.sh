#!/usr/bin/env bash
# Install Argo CD into namespace argocd.
# Run aws/helm/namespace/install.sh first. kubectl must already point at EKS.
set -euo pipefail

CHART_VERSION="${CHART_VERSION:-10.1.4}"
ARGO_NS="${ARGO_NS:-argocd}"
RELEASE="${RELEASE:-argocd}"
HELM_REPO_NAME="${HELM_REPO_NAME:-argo}"
HELM_REPO_URL="${HELM_REPO_URL:-https://argoproj.github.io/argo-helm}"
CLUSTER_NAME="${CLUSTER_NAME:-kong-ai-dev}"
AWS_REGION="${AWS_REGION:-us-east-2}"

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
VALUES="${ROOT}/aws/helm/argocd/values.yaml"
NS_INSTALL="${ROOT}/aws/helm/namespace/install.sh"

need() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "missing command: $1" >&2
    exit 1
  }
}

need helm
need kubectl

if [[ ! -f "$VALUES" ]]; then
  echo "values file not found: $VALUES" >&2
  exit 1
fi

echo "kubectl context: $(kubectl config current-context)"
if ! kubectl cluster-info >/dev/null 2>&1; then
  echo "kubectl cannot reach a cluster. AWS login is not EKS login." >&2
  echo "  aws eks update-kubeconfig --name ${CLUSTER_NAME} --region ${AWS_REGION}" >&2
  exit 1
fi

if ! kubectl get namespace "$ARGO_NS" >/dev/null 2>&1; then
  echo "namespace ${ARGO_NS} does not exist yet." >&2
  echo "Create it first:" >&2
  echo "  ${NS_INSTALL}" >&2
  exit 1
fi

echo "Installing Argo CD into namespace ${ARGO_NS} (Helm --namespace ${ARGO_NS})"
helm repo add "$HELM_REPO_NAME" "$HELM_REPO_URL" >/dev/null 2>&1 || helm repo add "$HELM_REPO_NAME" "$HELM_REPO_URL"
helm repo update >/dev/null

helm upgrade --install "$RELEASE" "${HELM_REPO_NAME}/argo-cd" \
  --version "$CHART_VERSION" \
  --namespace "$ARGO_NS" \
  --values "$VALUES" \
  --wait \
  --timeout 10m

echo
echo "Argo CD is in namespace ${ARGO_NS} (ClusterIP, no load balancer)."
echo "Admin password:"
kubectl -n "$ARGO_NS" get secret argocd-initial-admin-secret \
  -o jsonpath='{.data.password}' | base64 -d
echo
echo
echo "UI:"
echo "  kubectl -n ${ARGO_NS} port-forward svc/argocd-server 8080:80"
echo "  https://localhost:8080  user: admin"
