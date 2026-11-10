#!/usr/bin/env bash
set -euo pipefail

# Wait until the APIRule reports Ready and exposes a host.
# Usage: wait-apirule-ready.sh [namespace] [apirule-name] [max-attempts] [sleep-seconds]

NAMESPACE="${1:-${NAMESPACE:-dev}}"
APIRULE_NAME="${2:-${APIRULE_NAME:-hello-world}}"
MAX_ATTEMPTS="${3:-${MAX_ATTEMPTS:-30}}"
SLEEP_SECONDS="${4:-${SLEEP_SECONDS:-10}}"

for i in $(seq 1 "$MAX_ATTEMPTS"); do
  state="$(kubectl get apirule "$APIRULE_NAME" -n "$NAMESPACE" -o jsonpath='{.status.state}' 2>/dev/null || true)"
  host="$(kubectl get apirule "$APIRULE_NAME" -n "$NAMESPACE" -o jsonpath='{.spec.hosts[0]}' 2>/dev/null || true)"
  if [[ -z "$host" ]]; then
    host="$(kubectl get apirule "$APIRULE_NAME" -n "$NAMESPACE" -o jsonpath='{.spec.host}' 2>/dev/null || true)"
  fi

  echo "Attempt ${i}: state=${state:-<empty>} host=${host:-<empty>}"

  if [[ -n "$host" && "$state" == "Ready" ]]; then
    echo "APIRule '${APIRULE_NAME}' in namespace '${NAMESPACE}' is Ready."
    exit 0
  fi

  sleep "$SLEEP_SECONDS"
done

echo "APIRule '${APIRULE_NAME}' in namespace '${NAMESPACE}' did not become Ready in time." >&2
kubectl get apirule "$APIRULE_NAME" -n "$NAMESPACE" -o yaml || true
exit 1
