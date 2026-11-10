# demoappdeploytokyma

Minimal Node.js Hello World service deployed to SAP BTP Kyma on GCP.

## Run locally

```bash
npm test
npm start
curl http://localhost:3000/

# e2e against the local app (needs Node)
APP_VERSION=local npm start &
bash scripts/runTest.sh -e dev -v local -u http://localhost:3000
```

## Branching and deployment

This repository follows the FIPC branching strategy, adapted for Kyma. The full
contract, with diagrams for each scenario, is in
**[docs/branching-strategy.md](docs/branching-strategy.md)**.

| Branch | Workflow | Environment | Namespace | Deploy |
|---|---|---|---|---|
| `feature/**`, `bugfix/**`, `hotfix/**`, any PR | `ci.yaml` | none | — | build + test only |
| `develop` | `deploy-dev.yaml` | dev | `default` | automatic |
| `testing/**` | `deploy-dev.yaml` | dev | `default` | automatic |
| `master` | `deploy-qa.yaml` | qa | `demoapp-qa` | automatic |
| `rel.YYYY.MM.DD[-hotfix.N]` | `deploy-qa.yaml` | qa | `demoapp-qa` | automatic |
| `vYYYY.MM.DD[-hotfix.N]` | `deploy-prod.yaml` | prod | `demoapp-prod` | automatic, after the QA check and reviewer approval |

All three environments share **one** Kyma cluster (shoot `a35836f`, stage) and are
separated by namespace. Manifests are the Helm chart in [helm/demoapp](helm/demoapp),
with one values file per environment.

Dev and QA deploys run e2e after deploying and roll back automatically if it fails.
Prod only accepts a commit that passed QA. To test branching, e2e and rollback, follow
**[docs/demo-runbook.md](docs/demo-runbook.md)**.

Cutting a release:

```bash
# Release candidate: rel.2026.10.13 from master -> qa
git switch master
git pull --ff-only origin master
git switch -c rel.2026.10.13
git push -u origin rel.2026.10.13

# Release, once the rel.* QA run is green: v2026.10.13 -> prod (QA check + approval)
git fetch origin
git switch -c v2026.10.13 origin/rel.2026.10.13
git push -u origin v2026.10.13
```

## Published artifacts

Every dev and QA build publishes to Artifactory (`gtlc-production.common.repositories.cloud.sap`):

| Artifact | Where | Version |
|---|---|---|
| Image | `btp-gcp-test-<env>` (prod gets a copy of the QA image) | `<commit>` |
| Helm chart | `oci://.../btp-gcp-test-charts/demoapp` | `<Chart.yaml version>-<commit>`, e.g. `0.1.0-eea63a8...` |

Deploys install the chart from this repo. The published chart is a record of exactly what each commit shipped:

```bash
helm pull oci://gtlc-production.common.repositories.cloud.sap/btp-gcp-test-charts/demoapp --version 0.1.0-<commit>
```

Rollback doesn't use the published chart: Helm keeps each release's manifests as Secrets in the namespace and re-applies them, which pulls the old image from Artifactory again. Details: [docs/branching-strategy.md](docs/branching-strategy.md#artifacts).

## Public URLs

| Env | URL |
|---|---|
| dev | `https://demoapp-dev.a35836f.stage.kyma.ondemand.com` |
| qa | `https://demoapp-qa.a35836f.stage.kyma.ondemand.com` |
| prod | `https://demoapp.a35836f.stage.kyma.ondemand.com` |

## Required repository secrets

| Secret | Purpose |
|---|---|
| `GCP_KUBECONFIG_B64` | base64-encoded kubeconfig for the Kyma cluster, used by all three deploy workflows |
| `REGISTRY_USERNAME` | Artifactory login for pushing images and charts, also used to create the in-cluster pull secret |
| `REGISTRY_PASSWORD` | as above |

```bash
base64 < kyma.kubeconfig.yaml | tr -d '\n' \
  | GH_HOST=github.tools.sap gh secret set GCP_KUBECONFIG_B64 \
      --repo <owner>/<repo>
```

Each deploy job recreates its namespace and the `hello-world-registry` pull secret
idempotently, so there is no manual per-namespace bootstrap.

One-time repository setup (branch protection, the `production` environment and its
required reviewers): **[docs/branch-protection.md](docs/branch-protection.md)**.
