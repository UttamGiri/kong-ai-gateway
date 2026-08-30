#!/usr/bin/env bash
# Remove Istio ingress (the NLB) and optionally the whole mesh.
# Usage:
#   ./aws/helm/istio/uninstall.sh           # NLB + ingressgateway only
#   ./aws/helm/istio/uninstall.sh --all     # also istiod, CRDs, namespaces
set -euo pipefail

ALL=false
[[ "${1:-}" == "--all" ]] && ALL=true

ISTIO_SYSTEM_NS="${ISTIO_SYSTEM_NS:-istio-system}"
ISTIO_INGRESS_NS="${ISTIO_INGRESS_NS:-istio-ingress}"
CLUSTER_NAME="${CLUSTER_NAME:-kong-ai-dev}"
AWS_REGION="${AWS_REGION:-us-east-2}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"

need() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "missing command: $1" >&2
    exit 1
  }
}

need helm
need kubectl

if ! kubectl cluster-info >/dev/null 2>&1; then
  echo "  aws eks update-kubeconfig --name ${CLUSTER_NAME} --region ${AWS_REGION}" >&2
  exit 1
fi

echo "Removing Argo CD Istio Gateway/VS (NLB :8080)"
kubectl delete -f "${ROOT}/aws/helm/argocd/istio.yaml" --ignore-not-found

echo "Uninstalling Helm release istio-ingressgateway (this deletes the AWS NLB)"
helm uninstall istio-ingressgateway -n "$ISTIO_INGRESS_NS" --ignore-not-found || true

if [[ "$ALL" == true ]]; then
  echo "Uninstalling istiod + istio-base"
  helm uninstall istiod -n "$ISTIO_SYSTEM_NS" --ignore-not-found || true
  helm uninstall istio-base -n "$ISTIO_SYSTEM_NS" --ignore-not-found || true
  kubectl delete namespace "$ISTIO_INGRESS_NS" --ignore-not-found
  kubectl delete namespace "$ISTIO_SYSTEM_NS" --ignore-not-found
  echo "Set istio.enabled: false in aws/helm/kong-ai-gateway/values.yaml and push so Argo drops Gateway/VS."
fi

echo
echo "NLB is gone when Service istio-ingressgateway is gone:"
echo "  kubectl -n ${ISTIO_INGRESS_NS} get svc"
echo "  aws elbv2 describe-load-balancers --region ${AWS_REGION} --query 'LoadBalancers[].LoadBalancerName'"
