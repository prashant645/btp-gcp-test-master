#!/usr/bin/env bash
# Release gate: this commit must have a successful QA run on its matching rel.* branch.
# A QA run that failed e2e and rolled back is a failed run, so it doesn't count.
#
# Uses the GitHub Actions variables GITHUB_API_URL, GITHUB_REPOSITORY, GITHUB_REF_NAME
# and GITHUB_SHA, plus GH_TOKEN. There is no override.
set -euo pipefail

: "${GH_TOKEN:?GH_TOKEN is required}"

if [[ ! "$GITHUB_REF_NAME" =~ ^v[0-9]{4}\.[0-9]{2}\.[0-9]{2}(-hotfix\.[0-9]+)?$ ]]; then
  echo "Prod deploys only run from vYYYY.MM.DD[-hotfix.N] branches, not '$GITHUB_REF_NAME'." >&2
  exit 1
fi
RC_BRANCH="rel.${GITHUB_REF_NAME#v}"

URL="$GITHUB_API_URL/repos/$GITHUB_REPOSITORY/actions/workflows/deploy-qa.yaml/runs?branch=$RC_BRANCH&status=success&per_page=100"
if ! RUNS="$(curl -fsS -H "Authorization: Bearer $GH_TOKEN" -H "Accept: application/vnd.github+json" "$URL")"; then
  echo "Could not read QA runs from GitHub, so the gate is failing closed." >&2
  exit 1
fi

if grep -Eq "\"head_sha\": *\"$GITHUB_SHA\"" <<<"$RUNS"; then
  echo "QA passed for $GITHUB_SHA on $RC_BRANCH."
  exit 0
fi

echo "No successful QA run for $GITHUB_SHA on $RC_BRANCH. Fix it, or cut a new release candidate." >&2
exit 1
