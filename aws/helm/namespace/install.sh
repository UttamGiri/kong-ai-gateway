#!/usr/bin/env bash
# Create namespaces argocd and kong-ai-gateway. Run this BEFORE Argo CD.
# AWS CLI login is not enough: kubectl must already point at EKS.
set -euo pipefail

CLUSTER_NAME="${CLUSTER_NAME:-kong-ai-dev}"
AWS_REGION="${AWS_REGION:-us-east-2}"
HELM_RELEASE_NS="${HELM_RELEASE_NS:-kube-system}"

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
CHART="${ROOT}/aws/helm/namespace"

need() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "missing command: $1" >&2
    exit 1
  }
}

need helm
need kubectl

echo "kubectl context: $(kubectl config current-context)"
if ! kubectl cluster-info >/dev/null 2>&1; then
  echo "kubectl cannot reach a cluster. AWS login is not EKS login." >&2
  echo "Point kubeconfig at ${CLUSTER_NAME} (${AWS_REGION}):" >&2
  echo "  aws eks update-kubeconfig --name ${CLUSTER_NAME} --region ${AWS_REGION}" >&2
  echo "Then: kubectl get ns" >&2
  exit 1
fi

echo "Creating Namespace objects argocd and kong-ai-gateway"
echo "Helm release name platform-namespaces is stored in ${HELM_RELEASE_NS} (not where pods run)."

helm upgrade --install platform-namespaces "$CHART" \
  --namespace "$HELM_RELEASE_NS" \
  --wait

echo
kubectl get namespace argocd kong-ai-gateway
echo
echo "Next: ./aws/helm/argocd/install.sh"
