#!/usr/bin/env bash
# Install Istio (istiod + ingressgateway NLB). Then enable the Kong chart Istio objects.
# Extra AWS cost: NLB ~$0.66/day. Not ALB.
set -euo pipefail

CHART_VERSION="${CHART_VERSION:-1.30.3}"
ISTIO_SYSTEM_NS="${ISTIO_SYSTEM_NS:-istio-system}"
ISTIO_INGRESS_NS="${ISTIO_INGRESS_NS:-istio-ingress}"
HELM_REPO_NAME="${HELM_REPO_NAME:-istio}"
HELM_REPO_URL="${HELM_REPO_URL:-https://istio-release.storage.googleapis.com/charts}"
CLUSTER_NAME="${CLUSTER_NAME:-kong-ai-dev}"
AWS_REGION="${AWS_REGION:-us-east-2}"

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
ISTIOD_VALUES="${ROOT}/aws/helm/istio/istiod-values.yaml"
GATEWAY_VALUES="${ROOT}/aws/helm/istio/gateway-values.yaml"

need() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "missing command: $1" >&2
    exit 1
  }
}

need helm
need kubectl

HELM_BIN="${HELM_BIN:-helm}"
HELM_CLIENT_VER="$("$HELM_BIN" version --template '{{.Version}}' 2>/dev/null || echo v0.0.0)"
# Istio 1.24+ charts need Helm 3.14+. This machine may have 3.2.x.
if [[ "$HELM_CLIENT_VER" =~ ^v3\.([0-9]+)\. ]]; then
  minor="${BASH_REMATCH[1]}"
  if (( minor < 14 )); then
    TMP_HELM="$(mktemp -d)"
    arch="$(uname -m)"
    case "$arch" in
      x86_64) helm_arch=amd64 ;;
      arm64|aarch64) helm_arch=arm64 ;;
      *) echo "unsupported arch: $arch" >&2; exit 1 ;;
    esac
    echo "Helm ${HELM_CLIENT_VER} is too old for Istio ${CHART_VERSION}; using Helm 3.16.4"
    curl -fsSL "https://get.helm.sh/helm-v3.16.4-darwin-${helm_arch}.tar.gz" | tar -xz -C "$TMP_HELM"
    HELM_BIN="${TMP_HELM}/darwin-${helm_arch}/helm"
  fi
fi

echo "kubectl context: $(kubectl config current-context)"
if ! kubectl cluster-info >/dev/null 2>&1; then
  echo "  aws eks update-kubeconfig --name ${CLUSTER_NAME} --region ${AWS_REGION}" >&2
  exit 1
fi

"$HELM_BIN" repo add "$HELM_REPO_NAME" "$HELM_REPO_URL" >/dev/null 2>&1 || true
"$HELM_BIN" repo update >/dev/null

kubectl get namespace "$ISTIO_SYSTEM_NS" >/dev/null 2>&1 || kubectl create namespace "$ISTIO_SYSTEM_NS"
kubectl get namespace "$ISTIO_INGRESS_NS" >/dev/null 2>&1 || kubectl create namespace "$ISTIO_INGRESS_NS"

echo "Installing istio-base + istiod ${CHART_VERSION} into ${ISTIO_SYSTEM_NS}"
"$HELM_BIN" upgrade --install istio-base "${HELM_REPO_NAME}/base" \
  --version "$CHART_VERSION" \
  --namespace "$ISTIO_SYSTEM_NS" \
  --set defaultRevision=default \
  --wait \
  --timeout 5m

"$HELM_BIN" upgrade --install istiod "${HELM_REPO_NAME}/istiod" \
  --version "$CHART_VERSION" \
  --namespace "$ISTIO_SYSTEM_NS" \
  --values "$ISTIOD_VALUES" \
  --wait \
  --timeout 10m

echo "Installing istio-ingressgateway (NLB) into ${ISTIO_INGRESS_NS}"
"$HELM_BIN" upgrade --install istio-ingressgateway "${HELM_REPO_NAME}/gateway" \
  --version "$CHART_VERSION" \
  --namespace "$ISTIO_INGRESS_NS" \
  --values "$GATEWAY_VALUES" \
  --timeout 10m

echo
echo "Waiting for NLB hostname (can take 2–3 minutes)..."
for _ in $(seq 1 36); do
  HOST=$(kubectl -n "$ISTIO_INGRESS_NS" get svc istio-ingressgateway -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || true)
  if [[ -n "${HOST}" ]]; then
    echo "NLB: http://${HOST}"
    echo "After Kong Istio Gateway/VS sync: curl -sS -D - http://${HOST}/get"
    exit 0
  fi
  sleep 5
done

echo "NLB hostname not ready yet. Check:" >&2
echo "  kubectl -n ${ISTIO_INGRESS_NS} get svc istio-ingressgateway" >&2
exit 1
