# Branch protection and repository setup

Companion to [branching-strategy.md](branching-strategy.md). These are the settings
the branching strategy relies on that cannot live in the repository itself.

## 1. Migrate the branches

The strategy needs `develop` (default) and `master`. Skip this section if they
already exist - run `git branch -r` to check.

```bash
export GH_HOST=github.tools.sap
REPO=<owner>/<repo>

git fetch origin
git checkout -b develop origin/main && git push -u origin develop
git checkout -b master  origin/main && git push -u origin master

# Make develop the default so new PRs target it
gh repo edit "$REPO" --default-branch develop

# Re-target any open PRs onto develop, then retire main
gh pr list --repo "$REPO" --base main --json number \
  --jq '.[].number' | xargs -I{} gh pr edit {} --repo "$REPO" --base develop
git push origin --delete main
```

## 2. Apply protection

```bash
./scripts/apply-branch-protection.sh <owner>/<repo>
```

Confirm the CI status-check name first — it is the **job name**, not the workflow
file name:

```bash
GH_HOST=github.tools.sap gh pr checks <pr-number>
```

Protection applied to `develop` and `master`:

- required status check: the `CI` workflow's test job, strict (branch must be up to date)
- 1 approving review, stale reviews dismissed
- code-owner review required, which has no effect until you add `.github/CODEOWNERS`
- no force pushes, no deletions

## 3. Create the `production` environment

This is what gates the `v*` → prod deploy. It cannot be set from a file.

Settings → Environments → **New environment** → `production`:

- **Required reviewers**: the service owners
- **Deployment branches**: selected branches only — add the pattern `v*`
  (a deliberately wide safety net; the workflow trigger itself is narrower)
- (optional) wait timer

Without this environment the prod job runs unattended, which defeats the gate.

## 4. Protect the release branches

Add a branch ruleset covering `rel.*` and `v*`:

- block force pushes and deletions
- restrict creation to the release managers

Release branches are frozen artifacts. Create them only with the steps in
[branching-strategy.md](branching-strategy.md): `rel.*` from `master`, and `v*` from the
matching `origin/rel.*`.

## 5. Secrets

| Secret | Scope | Notes |
|---|---|---|
| `GCP_KUBECONFIG_B64` | repo | base64 kubeconfig for shoot `a35836f`, used by dev, qa **and** prod |
| `REGISTRY_USERNAME` | repo | Artifactory. Must be able to push images to `btp-gcp-test-<env>` and charts to `btp-gcp-test-charts` |
| `REGISTRY_PASSWORD` | repo | Artifactory |

All three environments share one cluster and therefore one kubeconfig, so
`GCP_KUBECONFIG_B64` must stay repository-scoped. Scoping it to the `production`
environment would break the dev and qa deploys.

That also means the `production` approval gate is the only thing separating a prod
deploy from a non-prod one at the credential level. If prod ever needs genuine
credential isolation, it needs its own cluster or its own service account, plus an
environment-scoped secret.

```bash
base64 < kyma.kubeconfig.yaml | tr -d '\n' \
  | GH_HOST=github.tools.sap gh secret set GCP_KUBECONFIG_B64 \
      --repo <owner>/<repo>
```

## 6. Runners

All jobs use `runs-on: self-hosted`, matching `hello-world-service-release-kyma`.
The Kyma API servers are not reachable from GitHub-hosted runners. The runner also
needs Docker for the image build.
