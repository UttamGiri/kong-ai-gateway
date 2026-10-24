#!/usr/bin/env bash
# Helm install for platform namespaces. EKS access entries come from Terraform workloads.
# Run AFTER terraform apply. Writes kubeconfig only (local laptop).
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

need aws
need helm
need kubectl

echo "=== AWS identity ==="
aws sts get-caller-identity
echo

if ! aws eks describe-cluster --name "$CLUSTER_NAME" --region "$AWS_REGION" >/dev/null 2>&1; then
  echo "cluster ${CLUSTER_NAME} not found in ${AWS_REGION}." >&2
  echo "Apply Terraform workloads first." >&2
  exit 1
fi

echo "=== kubeconfig ==="
aws eks update-kubeconfig --name "$CLUSTER_NAME" --region "$AWS_REGION"
echo "kubectl context: $(kubectl config current-context)"
echo

if ! kubectl get ns >/dev/null 2>&1; then
  echo "kubectl Unauthorized." >&2
  echo "Add your IAM principal to kubectl_admin_principal_arns in Terraform workloads and apply." >&2
  echo "  aws/terraform/workloads/dev/infra/access_entries.tf" >&2
  exit 1
fi

echo "=== Helm: namespaces argocd and kong-ai-gateway ==="
echo "Helm release platform-namespaces is stored in ${HELM_RELEASE_NS} (not where pods run)."
helm upgrade --install platform-namespaces "$CHART" \
  --namespace "$HELM_RELEASE_NS" \
  --wait

echo
kubectl get namespace argocd kong-ai-gateway
echo
echo "Next: ./aws/helm/argocd/install.sh"
