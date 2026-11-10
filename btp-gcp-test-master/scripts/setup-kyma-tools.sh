#!/usr/bin/env bash
set -euo pipefail

# Reusable CI helper for the Kyma deploy workflows:
#   - decode the base64 kubeconfig handed in as KYMA_KUBECONFIG_B64
#   - export KUBECONFIG for subsequent steps
#   - ensure kubectl, helm and yq are on PATH
#
# Modelled on hello-world-service's scripts/setup-kubeconfig-kubectl.sh.

KUBECONFIG_B64="${KYMA_KUBECONFIG_B64:-}"
KUBECONFIG_PATH="${KUBECONFIG_PATH:-/tmp/kubeconfig}"
KUBECTL_VERSION="${KUBECTL_VERSION:-v1.30.4}"
HELM_VERSION="${HELM_VERSION:-v3.15.4}"
YQ_VERSION="${YQ_VERSION:-v4.44.3}"

if [[ -z "$KUBECONFIG_B64" ]]; then
  echo "Missing base64 kubeconfig input. Set KYMA_KUBECONFIG_B64." >&2
  exit 1
fi

echo "$KUBECONFIG_B64" | base64 -d > "$KUBECONFIG_PATH"
chmod 600 "$KUBECONFIG_PATH"

if [[ -n "${GITHUB_ENV:-}" ]]; then
  echo "KUBECONFIG=$KUBECONFIG_PATH" >> "$GITHUB_ENV"
else
  export KUBECONFIG="$KUBECONFIG_PATH"
fi

mkdir -p "$HOME/bin"
if [[ -n "${GITHUB_PATH:-}" ]]; then
  echo "$HOME/bin" >> "$GITHUB_PATH"
fi
export PATH="$HOME/bin:$PATH"

if ! command -v kubectl >/dev/null 2>&1; then
  curl -fsSLo "$HOME/bin/kubectl" "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl"
  chmod +x "$HOME/bin/kubectl"
fi

if ! command -v helm >/dev/null 2>&1; then
  curl -fsSL "https://get.helm.sh/helm-${HELM_VERSION}-linux-amd64.tar.gz" \
    | tar -xz -C /tmp linux-amd64/helm
  mv /tmp/linux-amd64/helm "$HOME/bin/helm"
  chmod +x "$HOME/bin/helm"
fi

if ! command -v yq >/dev/null 2>&1; then
  curl -fsSLo "$HOME/bin/yq" "https://github.com/mikefarah/yq/releases/download/${YQ_VERSION}/yq_linux_amd64"
  chmod +x "$HOME/bin/yq"
fi

kubectl version --client
helm version --short
yq --version
