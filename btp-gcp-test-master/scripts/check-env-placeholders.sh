#!/usr/bin/env bash
set -euo pipefail

# Fail fast when an environment's values file still carries an unfilled
# placeholder (e.g. <QA_SHOOT>). Deploying it would create an APIRule with a
# bogus host. This is the "wired but inert" guard: master / rel.* / v* build and
# test, then stop here by design until the subaccount is provisioned.
#
# Usage: check-env-placeholders.sh <values-file>

VALUES_FILE="${1:?usage: check-env-placeholders.sh <values-file>}"

if [[ ! -f "$VALUES_FILE" ]]; then
  echo "Values file not found: $VALUES_FILE" >&2
  exit 1
fi

if grep -nE '<[A-Z0-9_]+>|PLACEHOLDER' "$VALUES_FILE"; then
  cat >&2 <<MSG

ERROR: $VALUES_FILE still contains placeholders (listed above).
Provision the target Kyma subaccount, then replace them with the real shoot id
and re-run.
MSG
  exit 1
fi

echo "No placeholders in $VALUES_FILE."
