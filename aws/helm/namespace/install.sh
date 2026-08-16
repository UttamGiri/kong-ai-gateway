#!/usr/bin/env bash
# Point this laptop at EKS, grant the current IAM principal cluster access,
# then create namespaces argocd and kong-ai-gateway. Run BEFORE Argo CD.
# Not Terraform. AWS CLI login is required; this script does the EKS side.
set -euo pipefail

CLUSTER_NAME="${CLUSTER_NAME:-kong-ai-dev}"
AWS_REGION="${AWS_REGION:-us-east-2}"
HELM_RELEASE_NS="${HELM_RELEASE_NS:-kube-system}"
ACCESS_POLICY_ARN="${ACCESS_POLICY_ARN:-arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy}"

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
CHART="${ROOT}/aws/helm/namespace"

need() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "missing command: $1" >&2
    exit 1
  }
}

aws_q() {
  aws --region "$AWS_REGION" "$@"
}

cluster_auth() {
  aws_q eks describe-cluster --name "$CLUSTER_NAME" \
    --query 'cluster.accessConfig.authenticationMode' --output text
}

cluster_status() {
  aws_q eks describe-cluster --name "$CLUSTER_NAME" \
    --query 'cluster.status' --output text
}

# IAM user ARN works as-is. Assumed-role STS ARNs must become the role ARN.
caller_principal_arn() {
  local arn account role
  arn="$(aws sts get-caller-identity --query Arn --output text)"
  if [[ "$arn" == *":assumed-role/"* ]]; then
    account="$(echo "$arn" | cut -d: -f5)"
    role="$(echo "$arn" | cut -d/ -f2)"
    echo "arn:aws:iam::${account}:role/${role}"
  else
    echo "$arn"
  fi
}

wait_until() {
  local desc="$1" tries="$2" delay="$3"
  shift 3
  local i=0
  while (( i < tries )); do
    if "$@"; then
      return 0
    fi
    sleep "$delay"
    i=$((i + 1))
  done
  echo "timed out waiting for ${desc}" >&2
  exit 1
}

is_cluster_active() {
  [[ "$(cluster_status)" == "ACTIVE" ]]
}

has_api_auth() {
  local mode
  mode="$(cluster_auth)"
  [[ "$mode" == "API" || "$mode" == "API_AND_CONFIG_MAP" ]]
}

kubectl_can_list_ns() {
  kubectl get ns >/dev/null 2>&1
}

policy_already_associated() {
  local count
  count="$(aws_q eks list-associated-access-policies \
    --cluster-name "$CLUSTER_NAME" \
    --principal-arn "$PRINCIPAL" \
    --query "length(associatedAccessPolicies[?policyArn=='${ACCESS_POLICY_ARN}'])" \
    --output text)"
  [[ "$count" != "0" && "$count" != "None" ]]
}

need aws
need helm
need kubectl

echo "=== AWS identity (this is who kubectl will present to EKS) ==="
aws sts get-caller-identity
PRINCIPAL="$(caller_principal_arn)"
echo "EKS access-entry principal: ${PRINCIPAL}"
echo

if ! aws_q eks describe-cluster --name "$CLUSTER_NAME" >/dev/null; then
  echo "cluster ${CLUSTER_NAME} not found in ${AWS_REGION}." >&2
  echo "Create EKS with Terraform workloads first. Do not run this script for that." >&2
  exit 1
fi

echo "Waiting for cluster ${CLUSTER_NAME} ACTIVE..."
wait_until "cluster ACTIVE" 60 5 is_cluster_active
echo "cluster status: $(cluster_status)"

if ! has_api_auth; then
  echo "authentication mode is $(cluster_auth). Switching to API_AND_CONFIG_MAP (access entries need this)."
  aws_q eks update-cluster-config \
    --name "$CLUSTER_NAME" \
    --access-config authenticationMode=API_AND_CONFIG_MAP \
    >/dev/null || true
  echo "Waiting for authentication mode API_AND_CONFIG_MAP..."
  wait_until "API_AND_CONFIG_MAP" 90 5 has_api_auth
fi
echo "authentication mode: $(cluster_auth)"
echo

echo "=== EKS access entry for ${PRINCIPAL} ==="
if aws_q eks describe-access-entry \
  --cluster-name "$CLUSTER_NAME" \
  --principal-arn "$PRINCIPAL" >/dev/null 2>&1; then
  echo "access entry already exists"
else
  aws_q eks create-access-entry \
    --cluster-name "$CLUSTER_NAME" \
    --principal-arn "$PRINCIPAL" \
    --type STANDARD
fi

if policy_already_associated; then
  echo "AmazonEKSClusterAdminPolicy already associated"
else
  aws_q eks associate-access-policy \
    --cluster-name "$CLUSTER_NAME" \
    --principal-arn "$PRINCIPAL" \
    --policy-arn "$ACCESS_POLICY_ARN" \
    --access-scope type=cluster
fi
echo

echo "=== kubeconfig ==="
aws_q eks update-kubeconfig --name "$CLUSTER_NAME"
echo "kubectl context: $(kubectl config current-context)"

echo "Waiting until kubectl can list namespaces..."
wait_until "kubectl get ns" 24 5 kubectl_can_list_ns
kubectl get ns
echo

echo "=== Helm: namespaces argocd and kong-ai-gateway ==="
echo "Helm release platform-namespaces is stored in ${HELM_RELEASE_NS} (not where pods run)."
helm upgrade --install platform-namespaces "$CHART" \
  --namespace "$HELM_RELEASE_NS" \
  --wait

echo
kubectl get namespace argocd kong-ai-gateway
echo
echo "Next: ./aws/helm/argocd/install.sh"
