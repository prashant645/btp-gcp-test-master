#!/usr/bin/env bash
# Records the live Helm release before a deploy, and restores it if verification fails.
#
#   rollback-release.sh record <namespace> <release>
#       Prints revision=<n> and version=<image tag>, for $GITHUB_OUTPUT.
#       Both are empty on a first-ever deploy.
#
#   rollback-release.sh restore <namespace> <release> <revision> <version> <host>
#       Rolls back, then checks the old image is live and the service answers.
set -euo pipefail

usage() {
  echo "usage: $0 record <namespace> <release>" >&2
  echo "       $0 restore <namespace> <release> <revision> <version> <host>" >&2
  exit 1
}

deployed_image() {
  kubectl get deployment "$2" -n "$1" -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null || true
}

record() {
  local ns="$1" release="$2" history revision image
  history="$(helm history "$release" -n "$ns" -o json 2>/dev/null || echo '[]')"
  # The last revision marked deployed; the newest revision may be a failed one.
  revision="$(yq '.[] | select(.status == "deployed") | .revision' <<<"$history" | tail -1)"
  image="$(deployed_image "$ns" "$release")"
  echo "revision=$revision"
  echo "version=${image##*:}"
}

restore() {
  local ns="$1" release="$2" revision="$3" version="$4" host="$5" image
  if [[ -z "$revision" ]]; then
    echo "First deploy of $release in $ns: nothing to roll back to. Leaving it up for debugging." >&2
    exit 1
  fi

  echo "Rolling back $release in $ns to revision $revision (version $version)"
  helm rollback "$release" "$revision" -n "$ns" --wait --timeout 3m

  image="$(deployed_image "$ns" "$release")"
  if [[ "${image##*:}" != "$version" ]]; then
    echo "Rollback check failed: deployment runs '${image##*:}', expected '$version'" >&2
    exit 1
  fi

  bash "$(dirname "${BASH_SOURCE[0]}")/smoke-test.sh" "$host"
  echo "/version now returns: $(curl -s "https://$host/version")"
  echo "Rolled back $release in $ns to version $version"
}

case "${1:-}" in
  record)  [[ $# -eq 3 ]] || usage; record "$2" "$3" ;;
  restore) [[ $# -eq 6 ]] || usage; restore "$2" "$3" "$4" "$5" "$6" ;;
  *) usage ;;
esac
