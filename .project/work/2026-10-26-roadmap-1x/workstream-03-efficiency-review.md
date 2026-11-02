---
title: Workstream 03 efficiency review
description: Review of all GitHub Actions workflows, with measured redundant tests and proposals to reduce work without weakening delivery gates.
type: review
status: final
areas: [ci, operations]
created: 2026-10-30
updated: 2026-10-30
agent_harness: GitHub Copilot CLI
agent_harness_version: 1.0.103
agent_model: GPT-6.1 Sol
agent_model_id: gpt-6.1-sol
reviewed_commit: 717c8a3c3302b2560858d8dac62168e788e884bb
---

# Workstream 03 efficiency review

## Scope and outcome

This reviews the efficiency of workstream 3, CI and publishing, in the [epic work plan](plan.md#3-ci-and-publishing). It covers all five workflow files, their scripts and build inputs, selected GitHub runs, and the required checks. It also covers generated CodeQL, which has no workflow file in the repo.

This adds to the final [workstream 3 correctness review](workstream-03-review.md). It does not replace or change it. The `work-reviewer` agent advised on format and prior decisions through Herdr. That advice is not a second correctness review.

**The main improvement is to skip expensive tests when none of their inputs changed.** Documentation-only work currently starts builds and clusters before and after merge. Keep each required check and explain any skipped work. Keep issue checks, fresh scans and release tests separate from this path decision.

The checkout was `release-1.11` at the commit above. GitHub settings and run results were read on 30 October 2026, from `00:58:26Z`. Source line references use that commit. Unrelated changes in `.project/README.md`, `.agents/` and `.project/intelligence/` were left untouched.

No workflow, policy, ruleset or publishing behavior changed. The maintainer must accept the proposals before a separate work package implements them.

## Workflow coverage and validated highlights

| Workflow | Triggers and purpose | Proposed action |
|---|---|---|
| [Tests](../../../.github/workflows/tests.yaml) | PRs and pushes to main/release branches, manual runs, and publishing calls. Tests the resolver, images and proxies on native amd64/arm64, and E2E on amd64 kind/k3d. | Select the expensive tests by changed inputs. Keep the cheap resolver tests and required check names. Always run the full suite for manual and publishing calls. |
| [Scan for vulnerabilities](../../../.github/workflows/scan-for-vulnerabilities.yaml) | PRs, branch pushes, manual runs and a daily schedule. Reports all findings and fails on fixable HIGH/CRITICAL findings. Schedule/manual runs also scan published `:1`. | Keep both scan targets. New vulnerabilities can appear without source changes. Keep reporting and failure rules unchanged. |
| [Publish images](../../../.github/workflows/build-and-publish-container-image.yaml) | `v*` and `publish-test-*` tags. Checks the tag, runs the full suite, publishes both platforms and signs provenance. | Keep tests on the tagged commit. Keep production tag checks, separate test tags and non-cancellation. Earlier PR results cannot replace these tests. |
| [PR issue check](../../../.github/workflows/pr-issue-check.yaml) | PR opened, edited, reopened and synchronized. Requires one open issue, with the existing Dependabot/release exceptions. | Run regardless of paths. Documentation PRs still need an issue. The observed job took seven seconds. |
| [PR labels](../../../.github/workflows/pr-labels.yaml) | The same PR events under `pull_request_target`. Sets area labels and copies issue type/milestone using base-branch code. | Run regardless of application paths. Documentation needs labels too. The workflow is not yet registered, so no live timing is available. Keep execution on trusted base code. |
| CodeQL, `dynamic/github-code-scanning/codeql` | Default setup for Actions and JavaScript/TypeScript. The [dependency/scanner plan](../2026-10-27-dependabot-and-codeql/plan.md) records its main/PR-to-main coverage and schedule. | Keep this separate code analysis. It did not run in the selected release-branch example. Do not change setup just to add path filters without evidence that this is needed. |

The API listed five registered workflows: Tests, scan, publish, issue check and CodeQL. The labels workflow was absent. `main` still had the older publish and scan files. An active workflow entry does not prove that the new daily source and published-image scans run. Verify those in 6.2.

Dependabot was not another registered workflow in this snapshot. Its [configuration](../../../.github/dependabot.yml) already schedules weekly updates and groups minor/patch releases. Keep its cooldown and security-update behavior.

## Measured example

PR #110 changed only:

- `.project/work/2026-10-26-roadmap-1x/plan.md`
- `.project/work/2026-10-26-roadmap-1x/workstream-03-review.md`

Both the PR and merge push ran the four expensive test jobs. The PR passed all seven required checks. These durations use job `completed_at - started_at`, for attempt 1:

| Work | PR job-seconds | Merge-push job-seconds | Total |
|---|---:|---:|---:|
| Four image/proxy and E2E jobs | 368 | 349 | 717 |
| Cheap `workflow-tests` job | 6 | 6 | 12 |
| Source scan job | 32 | 50 | 82 |
| PR issue check | 7 | Not triggered | 7 |
| All executed jobs above | 413 | 405 | 818 |

Tests used **729 job-seconds, or 12 minutes 9 seconds**, across the two runs. The eight expensive jobs used **717 seconds**. Each run took about 2 minutes 40 seconds because jobs ran in parallel.

These are observed durations, not billed minutes or savings already achieved. Path selection and the remaining jobs also take time. Do not promise to save the full 717 seconds.

Image builds took 7-9 seconds each. Tool installation took about one second. E2E steps took 112-139 seconds. Avoiding unneeded clusters is the better first target in this sample. These times need not represent every PR.

PR #108 shows why titles and labels are not enough. It concerned the devcontainer but also changed `test/ci/install-tools.sh`. CI uses that script, so both sets of expensive tests should run.

## Actionable efficiency findings

### 1. Select expensive tests, not whole workflow runs

In `tests.yaml:47-98`, the image and E2E jobs each build the app image. E2E also uses the chart, cluster configs, scenarios and `make e2e-image`. The image jobs call Docker directly. They do not use the Makefile.

For ordinary PRs and branch pushes, use this proposed map:

| Changed inputs | Image/proxy tests | E2E tests |
|---|---|---|
| `src/app/**`, including Dockerfile, lockfile, `.dockerignore`, static files and views | Run both architectures | Run both clusters |
| `test/image/run.sh`, `test/image/fake-arch.js`, `test/proxy/**` | Run both architectures | Skip |
| `deploy/helm/hello-kubernetes/**`, `test/e2e/**`, `Makefile` | Skip | Run both clusters |
| `test/ci/install-tools.sh`, `tests.yaml`, publishing test-gate wiring, or the selector and its fixtures | Run | Run |
| Resolver, resolver tests, or the two PR workflows using it | No expensive work; keep `workflow-tests` | No expensive work |
| `docs/**`, `.project/**`, root documentation or `.devcontainer/**` alone | Skip | Skip |
| `site/**` alone, when 5.1 creates it | Skip | Skip, unless E15 or another E2E test uses these files |
| Unclassified paths | Run, with the reason recorded | Run, with the reason recorded |

Check the whole changeset. Documentation plus an app change runs both sets of tests. Broad folder rules can run more tests than needed; they are not proof that every file has test coverage.

Work 4.5 rewrites docs. Work 5.1-5.4 adds the [site](../../roadmap/1.x/site.md). Name the site path when 5.1 creates it, rather than always treating it as unknown. Site-only changes should still run the site's own build and checks when those exist.

The planned E15 test in [testing.md](../../roadmap/1.x/testing.md) reads commands from documentation. When it lands, files it reads must trigger E2E. Apply the same rule to site files if a test starts using them. Do not infer this from a file extension or PR label.

Work 4.1 adds arm64 E2E jobs. Those jobs must run whenever E2E is needed. On 2026-10-30, the maintainer deferred P1 and the other proposals until after 1.11. Wait for 4.4 chart release, 4.6 Ingress/Gateway scenarios, the 5.x site build and E15 docs-as-tests. Then design the input map once. Do not defer arm64 coverage to save time.

### 2. Keep required checks and fail clearly

The ruleset requires `issue-check`, `workflow-tests`, `image-tests (amd64)`, `image-tests (arm64)`, `e2e (kind)`, `e2e (k3d)` and `scan-and-report-vulnerabilities`. It does not require the branch to be up to date. A skipped workflow can leave required checks pending. A skipped job can count as successful. Neither should hide a selection error.

A small first change can put selection in the required `workflow-tests` job. Keep the matrix jobs and their names. Skip only their expensive steps when no relevant input changed. Say what was skipped and why. This still starts runners, but does not require new ruleset entries.

Run selection before the resolver tests. Report whether selection succeeded, separately from the whole job's result. If selection passes but resolver tests fail, keep `workflow-tests` failed and run the selected image/E2E tests. Their results are still useful. A failed job in `needs` normally skips dependent jobs, so their conditions must allow this case. They must not allow selection failure or a cancelled run.

A selection error or missing/malformed output must fail the required check. Missing output is not `false`. A failed or cancelled selected test must block merge. A later design could require one final check instead of the matrix check names. That needs failure/cancellation tests and an agreed ruleset change.

For PRs, compare the merge base with the PR head, not just the latest commit. For pushes, compare the event's before/after SHAs. Include deletions and both sides of renames. Use event SHAs rather than moving branch names. If known history is unavailable, run the full suite and explain why. API errors or incomplete file lists must not silently mean no files changed. Check fork PRs with read-only permissions too.

Manual runs and publishing calls must run the full suite. Add an explicit reusable-workflow input that defaults to a full run. Set it explicitly in the publisher. Do not rely on `github.event_name == 'workflow_call'`: the called workflow sees its caller's event, a tag push here.

This changes the current every-PR policy. Update `AGENTS.md` and the testing/CI plan only after the maintainer accepts it.

### 3. Preserve useful PR, integration and release runs

A PR run and the push after merge test different revisions. Keep branch-push tests when relevant inputs change. Do not remove all push runs because a PR passed. Path selection can skip expensive work in both runs when their test inputs did not change.

Tests already cancels an older run when a new push updates the same PR. Keep that behavior and the decision not to cancel branch runs. Scan has no concurrency group. Consider PR-only cancellation later if repeated pushes waste enough scan time. Use a separate group and test upload/cancellation behavior. Do not cancel branch, scheduled or release runs without a new decision.

Publishing runs the full suite on the tag before registry writes. Keep version/main ancestry checks, native tests, GHCR-only test tags and `cancel-in-progress: false`. Earlier PR results cannot replace this run. Keep the checkout history that the ancestry check needs.

### 4. Keep fresh scans and their failure rules

The standalone scan runs twice over its image. One step reports all severities in SARIF. The other fails on fixable HIGH/CRITICAL findings. The API recorded the second step as zero seconds in both runs, at one-second resolution. This sample gives no reason to prioritize removing it.

Installed Trivy 0.76.1 supports report conversion, severity and exit-code options. Its `convert --help` does not expose the same `--ignore-unfixed` option. Prove that conversion keeps all findings and the same failure rule before reusing one report. Do not replace Trivy's rule with a custom JSON filter.

I4 scans each native image too. Those images differ by platform. I4 also runs in the standalone image tests and before publishing. The dedicated scan image has explicit OCI build metadata. Do not assume one result can replace all these scans. Keep them initially.

Daily source scans and scans of published `:1` check different artifacts. Keep both even when source files did not change. Use fresh vulnerability data. Keep all-severity reports, fixable HIGH/CRITICAL failure and fork upload restrictions. An old passing scan is not proof after the database changes. Verify the new schedule on `main` in 6.2.

### 5. Measure caching needs and keep metadata checks simple

The workflows have no explicit Docker layer cache between runs. BuildKit caching may help future builds, especially publishing. First measure runs with and without the cache, including transfers. The builds in this sample are short. E2E takes longer.

A cache must account for platform, Dockerfile, lockfile, base image and pinned tool/checksum changes. Keep checksum verification and read-only PR permissions. Keep untrusted PR caches separate from privileged publishing. If a cache is unavailable, build normally. Do not skip checks or add image transfers and registry writes just to save these short builds.

Issue checks and labels depend on current metadata, not only files. Do not apply application path selection to them or reuse stale issue results. The write-enabled labeler must still use trusted base code. It has no measured live cost yet. Keep CodeQL's separate analysis and schedule. Its absence on release PRs is a coverage limit, not a saving.

## Priorities and proof before adoption

**Decision, 2026-10-30: defer P1 and the other proposals until after 1.11.** Design the input map once all the 1.11 workflows and E15 exist. Runners are free for this public repo. The maintainer accepts about three minutes of check time per docs PR while we wait.

The priorities below are for that later work, not new issue assignments or changes to the 1.11 plans.

| Priority | Proposal | Proof needed |
|---|---|---|
| P1 | Add tested path selection and skip unneeded expensive steps | Correct file lists; unchanged required check names; logs explain skips; manual/publish runs stay full; failures block |
| P1 | Update contributor and testing instructions after acceptance | Instructions say which tests run and why |
| P2 | Check whether cancelling older PR scans is worth doing | Current-head results and SARIF uploads stay correct; branch/scheduled/publish runs are not cancelled |
| P2 | Test build/report reuse only if a measured delay remains | Include transfer time; test the right platform/commit; keep scan rules and release records |
| Keep | Cheap metadata checks, tagged-commit tests and fresh scans | Paths do not exempt issue association, release checks or new vulnerabilities |

Prove these cases before adoption:

| Case | Required outcome |
|---|---|
| Documentation-only PR and merge push, including 4.5 docs work | Logs explain skipped work; required checks complete |
| Site-only changes after 5.1 | No image/proxy or E2E work unless a test reads these files; site checks still run |
| Documentation/site files read by E15 or another E2E test | E2E runs |
| App plus documentation | Both architectures and both clusters run |
| Chart, E2E fixture or Makefile only | E2E runs |
| Image/proxy harness only | Both image/proxy architecture jobs run |
| Devcontainer plus shared tool installer | Both sets of expensive tests run |
| Selection, tests workflow or publishing call site changes | Full relevant suite, including tests of path selection |
| Selection passes but resolver tests fail | `workflow-tests` fails and blocks merge; selected image/E2E jobs still report results |
| Rename out of an input path, deletion or multi-commit PR | Relevant tests still run |
| Fork, new branch, unavailable history or incomplete API data | An explained full run or blocking error; never silently report no changes |
| Selection error, malformed output, selected-test failure or cancellation | Cannot pass merge/release checks by skipping work |
| Manual run and both publishing tag modes | Full suite on the requested/tagged commit |

Keep the prior review's assignments:

- **4.1:** arm64 default-chart E2E, real E3/E7 passes, and a unique startup-error filename.
- **4.4:** verify the published digest and distinguish Trivy infrastructure errors from vulnerabilities.
- **6.2:** prove real tags/signing on both registries, scheduled scans, labeler activation and cooldown compliance.

The deleted GHCR test tag was expected cleanup. Do not publish another one for this review.

## Review checks and limits

| Check | Result |
|---|---|
| All five workflow files and their inputs | Read at the recorded checkout; jobs, events, check names and release prerequisites traced |
| Live workflows, ruleset and CodeQL settings | Read on 30 October; seven required checks, CodeQL configured, labeler not registered |
| `main` workflow files and scan definition | Only the older publish/scan files present; new daily scans not yet proven |
| #110 and #108 changed files | Rechecked through GitHub; documentation-only evidence and shared-tool counterexample confirmed |
| Selected job/step timings | Recomputed from GitHub timestamps; original attempt, not a locally repeated benchmark |
| `trivy --version` and `trivy convert --help` | Checked installed 0.76.1 options only; did not scan or test equivalent failure behavior |
| Optimizations | Not implemented or benchmarked; the cases above are required proof for future work |

No app, image, cluster, publish or manual workflow run was started for this review. No registry writes, branches, commits or GitHub changes were made. The timings are a small sample. No net saving is claimed.

## Verification sources

- [#110 files](https://github.com/paulbouwer/hello-kubernetes/pull/110/files) and [#108 files](https://github.com/paulbouwer/hello-kubernetes/pull/108/files).
- [#110 Tests](https://github.com/paulbouwer/hello-kubernetes/actions/runs/40834310977), [merge Tests](https://github.com/paulbouwer/hello-kubernetes/actions/runs/40834840484), [PR scan](https://github.com/paulbouwer/hello-kubernetes/actions/runs/40834311079), [merge scan](https://github.com/paulbouwer/hello-kubernetes/actions/runs/40834840412), and [PR issue check](https://github.com/paulbouwer/hello-kubernetes/actions/runs/40834310978).
- Read-only API evidence: `repos/paulbouwer/hello-kubernetes/actions/workflows`, `rules/branches/release-1.11`, `code-scanning/default-setup`, `contents/.github/workflows?ref=main`, and each linked run's `jobs` endpoint.
- [CI work package](../2026-10-29-ci-tests/plan.md), [publish work package](../2026-10-29-publish-images/plan.md), [testing design](../../roadmap/1.x/testing.md#ci), and the [existing review and its verification sources](workstream-03-review.md#verification-sources).
- GitHub documentation: [path filtering and skipped workflows](https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-syntax#onpushpull_requestpull_request_targetpathspaths-ignore), [skipped job status](https://docs.github.com/en/actions/how-tos/write-workflows/choose-when-workflows-run/control-jobs-with-conditions), and [reusable workflow caller context](https://docs.github.com/en/actions/reference/workflows-and-actions/reusing-workflow-configurations#github-context).
