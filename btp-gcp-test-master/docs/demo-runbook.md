# Test runbook: branching and e2e

Run these 9 tests in order. Each one lists the exact steps and what must happen for it to pass. Record each result in the table at the end.

These pipelines haven't run on GitHub yet. If a run doesn't match a test's expected result, stop and fix that before moving on.

## Before you start

- The 3 repo secrets are set.
- The `production` environment exists in the repo, with at least one required reviewer. Without one, test 8 won't stop for approval.
- `git`, `curl`, `helm`, `rsync`, `perl` and Node are installed.
- Your working copy has no uncommitted changes when you run each test.

Set these in your terminal. Replace `<owner>/<repo>` and the kubeconfig path:

```bash
export REPO=<owner>/<repo>
export KUBECONFIG=~/path/to/kyma.kubeconfig.yaml
export DEV_URL=https://demoapp-dev.a35836f.stage.kyma.ondemand.com
export QA_URL=https://demoapp-qa.a35836f.stage.kyma.ondemand.com
export PROD_URL=https://demoapp.a35836f.stage.kyma.ondemand.com
export RELEASE=$(date +%Y.%m.%d)
```

Check every run under the repo's **Actions** tab.

## How to raise and merge a pull request

Pull requests are created and merged in the browser at `https://github.tools.sap/<owner>/<repo>`.

**To raise one:**
1. Open the **Pull requests** tab and click **New pull request**.
2. Set **base** to the target branch and **compare** to the source branch. Each test names both.
3. Click **Create pull request**, enter the title the test gives, and click **Create pull request** again.

**To merge one:**
1. Wait until **CI** shows green in the checks at the bottom of the PR.
2. In the merge button's dropdown, choose **Create a merge commit**. Don't use squash or rebase, because test 4 reverts a merge commit.
3. Click **Merge pull request**, then **Confirm merge**.
4. If the test says so, click **Delete branch**. Never delete `develop` or `master`.

## Test 1: Push the pipeline to `develop` and `master`

Replace `<this folder>` with the folder containing this code:

```bash
git clone "https://github.tools.sap/$REPO.git" btp-demo-test
cd btp-demo-test
git switch develop || git switch -c develop
rsync -a --exclude .git "<this folder>/" ./
git add -A
git commit -m "Add post-deploy e2e, rollback and QA gate"
git push -u origin develop
```

Then update `master`. If it doesn't exist yet, run `git push origin develop:master` instead of raising a PR.

**PR:** base `master`, compare `develop`, title `Add e2e pipeline`. Merge it, and keep the branch.

**Pass when:**
- **Deploy – dev** and **Deploy – qa** are both green.
- `curl -s "$DEV_URL/version"` prints the `develop` commit from `git rev-parse origin/develop`.
- `curl -s "$QA_URL/version"` prints the `master` commit from `git rev-parse origin/master`, after `git fetch`.

## Test 2: A PR runs CI and doesn't deploy

```bash
git switch develop && git pull
git switch -c feature/demo-change
echo "Demo change." >> README.md
git commit -am "Demo change"
git push -u origin feature/demo-change
```

**PR:** base `develop`, compare `feature/demo-change`, title `Demo change`. Don't merge it yet.

**Pass when:**
- **CI** is green on the PR.
- No **Deploy – dev** run started.
- `curl -s "$DEV_URL/version"` hasn't changed.

## Test 3: Merging to `develop` deploys to dev and runs e2e

Merge the `Demo change` PR from test 2, then delete the branch. Then update your copy:

```bash
git switch develop && git pull
```

**Pass when:**
- **Deploy – dev** shhi sirows Build & Test, Deploy, APIRule + smoke and e2e all green, and Rollback skipped.
- The Build & Test log's *Publish Helm chart* step ends with `Published oci://gtlc-production.common.repositories.cloud.sap/btp-gcp-test-charts/demoapp:0.1.0-<commit>`, and the chart is visible in Artifactory under `btp-gcp-test-charts/demoapp`.
- The e2e log ends with `Test Execution ===> SUCCESS`.
- The run has an `e2e-results-dev` artifact.
- `curl -s "$DEV_URL/version"` prints the same commit as `git rev-parse HEAD`.

## Test 4: A bug on `develop` fails e2e, Kubernetes rolls back, and you revert the code

This bug passes the unit tests and the smoke test. It only appears in the deployed image, which sets `NODE_ENV=production`.

The rollback only fixes the cluster. The bug stays on `develop` until you revert it, and until then every dev deploy from `develop` fails and rolls back. **Don't promote `develop` to `master` until step 4 is done.**

**Step 1: In Terminal 1, watch the live version.** Leave it running.

```bash
while true; do printf '%s  ' "$(date +%T)"; curl -s -m 5 "$DEV_URL/version"; echo; sleep 5; done
```

**Step 2: In Terminal 2, push the bug and raise a PR.**

```bash
git switch develop && git pull
export GOOD=$(git rev-parse HEAD)      # the version rollback must restore
echo "$GOOD"
git switch -c feature/rollback-demo
perl -pi -e "s/process\.env\.APP_VERSION \|\| 'unknown'/process.env.NODE_ENV === 'production' ? 'broken' : (process.env.APP_VERSION || 'unknown')/" server.js
npm test
git commit -am "Rollback demo: bug only visible once deployed"
git push -u origin feature/rollback-demo
```

**PR:** base `develop`, compare `feature/rollback-demo`, title `Rollback demo`. Wait for **CI** to go green.

**Step 3: Merge it, and let the rollback happen.**

Merge the PR with **Create a merge commit**, then delete the branch. Then, in Terminal 2:

```bash
git switch develop && git pull
export BAD_MERGE=$(git rev-parse HEAD)
git log -1 --oneline "$BAD_MERGE"     # must show "Merge pull request ... feature/rollback-demo"
```

**Pass when:**
- `npm test` passed and **CI** is green on the PR.
- **Deploy – dev** shows Build & Test, Deploy and APIRule + smoke green, **e2e red**, Rollback green, and the whole run red.
- The e2e log shows `expected 'broken' to deeply equal '<commit>'`.
- The Rollback log ends with `Rolled back hello-world in default to version <$GOOD>`.
- Terminal 1 goes from `$GOOD` to `broken`, then back to `$GOOD`.
- `helm history hello-world -n default` shows a newest revision with status `deployed` and description `Rollback to <n>`.
- `git log -1 origin/develop` still shows the bug's merge commit, so the code hasn't been reverted yet.

**Step 4: Revert the commit by hand.**

```bash
git switch -c bugfix/revert-rollback-demo
git revert -m 1 "$BAD_MERGE" --no-edit
git push -u origin bugfix/revert-rollback-demo
```

**PR:** base `develop`, compare `bugfix/revert-rollback-demo`, title `Revert rollback demo`. Wait for **CI** to go green, merge it, and delete the branch. Then:

```bash
git switch develop && git pull
```

**Pass when:**
- `git diff "$GOOD" HEAD -- server.js` prints nothing.
- **Deploy – dev** is green on the revert merge, with Rollback skipped.
- `curl -s "$DEV_URL/version"` prints the same commit as `git rev-parse HEAD`.

Stop Terminal 1 with `Ctrl+C`.

## Test 5: Merging to `master` deploys to QA and runs e2e

**PR:** base `master`, compare `develop`, title `Promote to QA`. Merge it, and keep the branch.

**Pass when:**
- **Deploy – qa** is green, with Rollback skipped.
- `curl -s "$QA_URL/version"` prints the new `master` commit from `git rev-parse origin/master`, after `git fetch`.

## Test 6: A release candidate deploys to QA and runs e2e

Create the release candidate branch from the latest `master` and push it. Pushing it starts the QA deploy:

```bash
git switch master
git pull --ff-only origin master
git switch -c "rel.$RELEASE"
git push -u origin "rel.$RELEASE"
```

The name must be exactly `rel.YYYY.MM.DD`, for example `rel.2026.11.10`. Any other name, such as `rel-2026.11.10`, starts no QA deploy.

**Pass when:**
- A `rel.<date>` branch exists.
- **Deploy – qa** is green on that branch.

Wait for this run to finish before test 8.

## Test 7: A commit with no QA run can't reach prod

```bash
git switch develop && git pull
git switch -c v2026.01.01
git push -u origin v2026.01.01
```

**Pass when:**
- **Deploy – prod** is red at *QA passed for this commit*.
- The log shows `No successful QA run for <commit> on rel.2026.01.01`.
- *Deploy* is skipped and no approval is requested.
- `curl -s "$PROD_URL/version"` hasn't changed.

Clean up:

```bash
git switch develop
git branch -D v2026.01.01
git push origin --delete v2026.01.01
```

## Test 8: A commit that passed QA reaches prod after approval

Create the release branch from the remote release candidate, so it's the exact commit QA tested, and push it. Pushing it starts the prod deploy:

```bash
git fetch origin
git switch -c "v$RELEASE" "origin/rel.$RELEASE"
git push -u origin "v$RELEASE"
```

The run stops and waits for review. A required reviewer opens the run in **Actions**, clicks **Review deployments**, ticks `production` and clicks **Approve and deploy**.

**Pass when:**
- The log shows `QA passed for <commit> on rel.<date>`.
- The run waits for approval before *Deploy* starts.
- After approval, **Deploy – prod** is green.
- `curl -s "$PROD_URL/version"` prints the same commit as `git rev-parse "origin/rel.$RELEASE"`.

## Test 9: A hotfix goes through `master`, QA and prod

```bash
git switch master && git pull
git switch -c hotfix/demo-fix
echo "Hotfix demo." >> README.md
git commit -am "Hotfix demo"
git push -u origin hotfix/demo-fix
```

**PR:** base `master`, compare `hotfix/demo-fix`, title `Hotfix demo`. Wait for **CI** to go green, merge it, and delete the branch.

Create the hotfix release candidate from `master` and push it. This starts the QA deploy:

```bash
git switch master
git pull --ff-only origin master
git switch -c "rel.$RELEASE-hotfix.1"
git push -u origin "rel.$RELEASE-hotfix.1"
```

Wait for **Deploy – qa** to go green on `rel.<date>-hotfix.1`. Then create the hotfix release branch from it and push it. This starts the prod deploy:

```bash
git fetch origin
git switch -c "v$RELEASE-hotfix.1" "origin/rel.$RELEASE-hotfix.1"
git push -u origin "v$RELEASE-hotfix.1"
```

A required reviewer then approves it, as in test 8.

**Pass when:**
- **CI** is green on the PR.
- **Deploy – qa** is green on `rel.<date>-hotfix.1`.
- **Deploy – prod** is green on `v<date>-hotfix.1`.
- `curl -s "$PROD_URL/version"` prints the same commit as `git rev-parse "origin/rel.$RELEASE-hotfix.1"`.

Then bring the fix back into `develop`, so the next release doesn't lose it.

**PR:** base `develop`, compare `master`, title `Bring hotfix into develop`. Merge it, and keep the branch.

**Pass when:** **Deploy – dev** is green and `git log origin/develop --oneline` includes `Hotfix demo`, after `git fetch`.

## Results

| Test | Proves | Passed? | Run link | Date |
|---|---|---|---|---|
| 1 | Pipeline is live on both branches | | | |
| 2 | A PR runs CI and doesn't deploy | | | |
| 3 | `develop` deploys to dev, then e2e runs | | | |
| 4 | Failed e2e rolls back dev, then a manual revert fixes `develop` | | | |
| 5 | `master` deploys to QA, then e2e runs | | | |
| 6 | `rel.*` deploys to QA, then e2e runs | | | |
| 7 | A commit with no QA pass is blocked from prod | | | |
| 8 | A commit that passed QA reaches prod after approval | | | |
| 9 | Hotfix path works | | | |

## If a test fails

| What you see | What to do |
|---|---|
| Build & Test fails at *Publish Helm chart* with `401`, `403` or `denied` | The registry account can't write to `btp-gcp-test-charts`. Ask the Artifactory owners for push rights, or change `CHART_REPO` in `.github/workflows/wf-deploy-e2e.yaml`. Nothing was deployed. |
| `Could not install Newman` | The runner can't reach npm. Point npm at the internal registry, or install Newman on the runner. |
| Certificate error in e2e | The runner doesn't trust the certificate. Add the CA with Newman's `--ssl-extra-ca-certs`. Don't use `--insecure`. |
| e2e fails on `POST is not successful` | Check `apirule.methods` in `helm/demoapp/values.yaml`. Only `GET` should be listed. |
| *Deploy* is red and Rollback is skipped | Expected: `--atomic` has already reverted it. Check the pod events and the `hello-world-registry` pull secret. |
| `nothing to roll back to` | It's the first deploy of that release. Deploy a good version, then repeat the test. |
| `No successful QA run` in test 8 or 9 | QA failed or hadn't finished. Wait for a green `rel.*` run, then click **Re-run all jobs** on the prod run. |
| Prod deployed without approval | Add a required reviewer to the `production` environment. |
| No **Deploy – qa** or **Deploy – prod** run after pushing a `rel.*` or `v*` branch | The name doesn't match `rel.YYYY.MM.DD[-hotfix.N]` or `vYYYY.MM.DD[-hotfix.N]`. Delete the branch with `git push origin --delete <branch>` and push it again with the right name. |
| `a branch named ... already exists` from `git switch -c` | That release was already cut. Set `RELEASE` to a new `YYYY.MM.DD` value. |
| In test 4, `git log -1 "$BAD_MERGE"` isn't a `Merge pull request` commit | The PR was squashed or rebased. Revert with `git revert "$BAD_MERGE" --no-edit`, without `-m 1`. |
| Merge button is greyed out | **CI** hasn't finished or is red, or branch protection needs an approval from someone other than you. |
