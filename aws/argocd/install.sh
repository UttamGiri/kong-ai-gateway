#!/usr/bin/env bash
# Register the Helm chart with Argo CD. Namespace kong-ai-gateway must already exist.
# Image must already be on Docker Hub (Actions → Docker publish Kong AI Gateway).
set -euo pipefail

CLUSTER_NAME="${CLUSTER_NAME:-kong-ai-dev}"
AWS_REGION="${AWS_REGION:-us-east-2}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
APP="${ROOT}/aws/argocd/kong-ai-gateway.yaml"

need() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "missing command: $1" >&2
    exit 1
  }
}

need kubectl

echo "kubectl context: $(kubectl config current-context)"
if ! kubectl cluster-info >/dev/null 2>&1; then
  echo "  aws eks update-kubeconfig --name ${CLUSTER_NAME} --region ${AWS_REGION}" >&2
  exit 1
fi

if ! kubectl get namespace kong-ai-gateway >/dev/null 2>&1; then
  echo "namespace kong-ai-gateway missing. Run ./aws/helm/namespace/install.sh first." >&2
  exit 1
fi

if ! kubectl get namespace argocd >/dev/null 2>&1; then
  echo "namespace argocd missing. Install Argo CD first." >&2
  exit 1
fi

kubectl apply -f "$APP"
echo
echo "Argo CD Application kong-ai-gateway → namespace kong-ai-gateway"
echo "UI: http://localhost:8080  (port-forward argocd-server)"
echo "  kubectl -n argocd port-forward svc/argocd-server 8080:80"
