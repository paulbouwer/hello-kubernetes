---
title: 1.x roadmap
description: Deliver the 1.x roadmap in the 1.11 release, then deprecate the old image tags.
type: plan
status: active
areas: [app, image, deploy, ci, site, operations]
created: 2026-10-26
updated: 2026-10-29
---

# 1.x roadmap

## Intent

Bring hello-kubernetes 1.x up to date in one release, 1.11.0. The release gives a patched and supported image for amd64 and arm64, a secure Helm chart that can create an Ingress or an HTTPRoute, tests on real clusters, current docs, and a website. People who use the defaults today must see no change in behaviour, apart from the fixes that the plan lists. After the release, the old image tags get deprecation warnings, and the main upstream users are told about the upgrade.

The *why* and *how* for each area is in the [1.x roadmap](../../roadmap/1.x/README.md). This plan says what we build, in which order, which rules apply, and how we prove that the result is good. The scope is set by [GOAL.md](../../GOAL.md).

## Decisions

Made on 2026-10-26. The roadmap notes are updated to match.

| Decision | Result |
|---|---|
| What goes in 1.11 | All the work in the 1.x roadmap. Only the deprecation images and the upstream PRs come after the release. |
| Breaking chart changes | Wait for 2.0. In 1.x, `rewritePath` stays `true` by default, the Service stays `LoadBalancer`, and the old `ingress.configured`, `ingress.pathPrefix` and `ingress.rewritePath` values keep working. The new top-level `pathPrefix` and `rewritePath` values are added beside them. |
| Distroless base image | Not in 1.x. `node:24-alpine` only. |
| How the page gets the architecture | At runtime, from `process.platform` and `process.arch`, mapped to OCI names (`x64` → `amd64`). `info.json` is removed. This is the approach from PR #40. These values come from the Node binary, so they show the image's platform, not the host's. |
| Due date of the `v1.11` milestone | Stays at 2026-10-30 for now. To be looked at again. |
| Grouping name | *Workstream*. |

## Tracking

- **One epic issue**, [#54](https://github.com/paulbouwer/hello-kubernetes/issues/54) `chore(roadmap): deliver the 1.x roadmap`, pinned. It links to this plan. All work issues are direct sub-issues of it (one level only), so the sub-issue progress bar counts all of them.
- **The epic body groups the sub-issues by workstream.** There is one heading for each workstream, under **1.11** and **After 1.11**. The body is kept up to date by hand: when you create a sub-issue, add it under its heading in the same step. See [Epic body](#epic-body).
- **No Workstream field on the board.** The epic body is the only place that records the workstream.
- **Milestones:** work issues for 1.11 are in `v1.11`. The work after 1.11 has no milestone. The epic has no milestone. It closes when the work after 1.11 is done.
- **Order:** set with "blocked by" issue dependencies, from the **Blocked by** column below.
- **PRs:** one PR resolves one issue. A large issue can have more than one PR. A PR never spans two issues. If two issues can't be split, merge them into one issue.
- **IDs** such as `2.4` are for planning only. When the issues exist, issue numbers replace them in the epic body.

## Work

The labels follow [operations.md](../../roadmap/1.x/operations.md#labels-15). "Blocked by" uses the IDs in these tables.

### 1.11

#### 1. Foundations

The [workstream 1 review](workstream-01-review.md) records the outcome and the follow-up needed before automatic PR labelling goes live.

| ID | Issue title | Labels | Blocked by | Resolves | Plan |
|---|---|---|---|---|---|
| 1.1 | chore(repo): set up the labels, board statuses and board workflows | enhancement, area:operations | — | — | [work package](../2026-10-26-labels-and-board/plan.md), [operations.md](../../roadmap/1.x/operations.md#setting-up-the-labels) |
| 1.2 | chore(repo): add AGENTS.md, CONTRIBUTING.md, templates, labeler, release notes config and the PR issue check | enhancement, area:operations | 1.1 | — | [work package](../2026-10-26-contributing-and-checks/plan.md), [operations.md](../../roadmap/1.x/operations.md#supporting-files) |
| 1.3 | chore(triage): label the open items and close the off-topic PRs | enhancement, area:operations | 1.1 | #48, #41, #43 | [work package](../2026-10-27-community-triage/plan.md), [community.md](../../roadmap/1.x/community.md) |
| 1.4 | chore(deps): add Dependabot and CodeQL | enhancement, area:operations | 1.1 | — | [work package](../2026-10-27-dependabot-and-codeql/plan.md), [image.md](../../roadmap/1.x/image.md#what-github-provides) |

#### 2. Image and app

| ID | Issue title | Labels | Blocked by | Resolves | Plan |
|---|---|---|---|---|---|
| 2.1 | fix(image): move to node:24-alpine with a lockfile and a numeric non-root user | security, area:image | — | #35 (image), #45 | [work package](../2026-10-28-node24-image/plan.md), [image.md](../../roadmap/1.x/image.md#step-1-node24-alpine) |
| 2.2 | chore(app): upgrade express, pino-http and express-handlebars | enhancement, area:app | 2.1 | — | [work package](../2026-10-28-app-dependencies/plan.md), [image.md](../../roadmap/1.x/image.md#dependency-upgrades) |
| 2.3 | fix(app): load assets correctly when RENDER_PATH_PREFIX is not set | bug, area:app | 2.2 | #38 | [work package](../2026-10-28-asset-paths/plan.md), [community.md](../../roadmap/1.x/community.md#incorporate-in-spirit) |
| 2.4 | feat(app): show the image architecture from the runtime | enhancement, area:app | 2.2 | #40 (in spirit) | [work package](../2026-10-28-runtime-architecture/plan.md), [image.md](../../roadmap/1.x/image.md#supported-amd64-and-arm64) |
| 2.5 | test(e2e): add the e2e harness and the first scenarios on kind and k3d | enhancement, area:ci | — | — | [work package](../2026-10-28-e2e-harness/plan.md), [testing.md](../../roadmap/1.x/testing.md#suggested-order) step 1 |
| 2.6 | test(image): add the image tests | enhancement, area:ci | 2.1, 2.4 | — | [work package](../2026-10-29-image-tests/plan.md), [testing.md](../../roadmap/1.x/testing.md#image-tests) |

2.5 covers `lib.sh`, `run.sh`, the kind and k3d configs, and E1–E4, E7 and E11 on both clusters ([work package](../2026-10-28-e2e-harness/plan.md)). E3 and E7 are expected failures until 4.1 (decided 2026-10-28: k3d moved from 4.6 into 2.5).

#85, found while reviewing 2.4, makes the app run from any directory and adds `make run` ([work package](../2026-10-28-run-locally/plan.md)).

2.2 also adds a SIGTERM handler to `server.js`, so the app stops at once instead of waiting 10 to 30 seconds for the grace period. 2.1 verifies the image on amd64 only. The arm64 checks run in the CI matrix in 3.3 (both decided 2026-10-28).

The [workstream 2 review](workstream-02-review.md) records the outcome and the follow-up needed before arm64 CI.

#### 3. CI and publishing

| ID | Issue title | Labels | Blocked by | Resolves | Plan |
|---|---|---|---|---|---|
| 3.1 | ci(scan): rebuild the vulnerability scan so it fails on fixable findings | security, area:ci | 2.1 | open code-scanning alerts | [work package](../2026-10-29-vulnerability-scan/plan.md), [image.md](../../roadmap/1.x/image.md#trivy-installed-safely) |
| 3.2 | ci(publish): publish amd64 and arm64 images to Docker Hub and GHCR | enhancement, area:ci, area:image | 2.1, 2.4 | #40, #46 | [work package](../2026-10-29-publish-images/plan.md), [review.md](../../roadmap/1.x/review.md#fixes-effort-and-impact) row 4 |
| 3.3 | ci(e2e): run the image and e2e tests on amd64 and arm64 | enhancement, area:ci | 2.5, 2.6 | — | [work package](../2026-10-29-ci-tests/plan.md), [workstream 2 review](workstream-02-review.md#follow-up-before-arm64-ci), [testing.md](../../roadmap/1.x/testing.md#ci) |
| 3.4 | fix(ci): find the PR's issue the same way in the labels workflow and the issue check | security, area:ci | 1.2 | — | [workstream 1 review](workstream-01-review.md#finding-to-address) |

- 3.1 scans on PRs, on pushes to `main` and `release-*`, and every day, and reports every finding to code scanning. The 10 old Trivy alerts close when the scan runs on `main`, after 1.11 merges.
- 3.2 includes SBOM and provenance, closes CodeQL alert #67 (no `permissions:` block), and adds a daily scan of the published image (`paulbouwer/hello-kubernetes:1`), which shows when a patch release is due.
- 3.3 runs the image tests (I1–I7, I5a) on native amd64 and arm64 runners, the proxy tests, and the e2e tests on amd64 on kind and k3d, as required checks before publishing. It loads a single-platform image into each cluster. It also hardens the harness, from the workstream 2 review: an `EXPECTED_FAILURE` names the error it expects, so a different failure is a FAIL; a failed cluster deletion is reported; and the image tests show Docker's errors when a container doesn't start. The arm64 e2e job comes with 4.1, because the chart pins pods to amd64 until then.
- 3.4 comes from the workstream 1 review. It must land before 6.2, when automatic PR labelling goes live on `main`.

#### 4. Chart and deployment

| ID | Issue title | Labels | Blocked by | Resolves | Plan |
|---|---|---|---|---|---|
| 4.1 | fix(chart): add secure defaults and fix the chart bugs | bug, area:deploy | 2.1 | #35 (chart) | [deploy.md](../../roadmap/1.x/deploy.md#helm-version), [review.md](../../roadmap/1.x/review.md#fixes-effort-and-impact) row 6 |
| 4.2 | feat(chart): create an Ingress or an HTTPRoute from the chart | enhancement, area:deploy | 4.1 | #31 | [deploy.md](../../roadmap/1.x/deploy.md#exposing-the-app) |
| 4.3 | feat(chart): add values.schema.json | enhancement, area:deploy | 4.2 | — | [site.md](../../roadmap/1.x/site.md#agent-experience-ax) |
| 4.4 | ci(release): publish the rendered YAML and the OCI chart with each release | enhancement, area:ci, area:deploy | 3.2, 4.2 | #29, #23 | [deploy.md](../../roadmap/1.x/deploy.md#rendered-yaml-on-each-release) |
| 4.5 | docs(deploy): rewrite the deployment docs for Helm, kubectl and Kustomize | documentation, area:deploy | 4.2, 4.4 | #28, #31 | [deploy.md](../../roadmap/1.x/deploy.md) |
| 4.6 | test(e2e): add Ingress and Gateway API scenarios on kind and k3d | enhancement, area:ci | 3.3, 4.2 | — | [testing.md](../../roadmap/1.x/testing.md#suggested-order) steps 2–4, 7, 8 |

- 4.1 covers the `securityContext`, removing `kubernetes.io/arch: amd64` from `nodeSelector`, quoting `message` and `pathPrefix`, `appVersion`, and `NOTES.txt`. It removes the `EXPECTED_FAILURE` markers from E3 and E7, and adds the arm64 e2e job to CI, which proves the default chart on arm64 (workstream 2 review).
- 4.2 also adds the top-level `pathPrefix` and `rewritePath`, and keeps the old names working.
- 4.4 includes the Artifact Hub listing.
- 4.5 covers the quick start with clean-up, Helm 3.x or 4.x, the NGINX, Traefik and Gateway API examples, the Kustomize guide and the values reference.
- 4.6 covers E5, E6, E8–E10 and E12–E18.

#### 5. Website

| ID | Issue title | Labels | Blocked by | Resolves | Plan |
|---|---|---|---|---|---|
| 5.1 | feat(site): scaffold the Starlight site and publish it to GitHub Pages | enhancement, area:site | 4.5 | — | [site.md](../../roadmap/1.x/site.md#hosting-and-build) |
| 5.2 | feat(site): style the docs and add llms.txt | enhancement, area:site | 5.1 | — | [site.md](../../roadmap/1.x/site.md#docs) |
| 5.3 | feat(site): add the landing page | enhancement, area:site | 5.1 | — | [site.md](../../roadmap/1.x/site.md#landing-page) |
| 5.4 | feat(site): add the config builder and the live preview | enhancement, area:site | 4.3, 5.3 | — | [site.md](../../roadmap/1.x/site.md#config-builder) |

5.2 also covers `llms-full.txt` and the hidden note for agents on each page.

#### 6. Release

| ID | Issue title | Labels | Blocked by | Resolves | Plan |
|---|---|---|---|---|---|
| 6.1 | docs(project): write and approve the deprecation plan for the old tags | documentation, area:operations | — | — | [review.md](../../roadmap/1.x/review.md#deprecation-images-for-the-old-tags) |
| 6.2 | chore(release): release 1.11.0 | enhancement, area:operations | all 1.11 issues | #40, #45, #46 | [review.md](../../roadmap/1.x/review.md#about-archiving-the-old-tags), [community.md](../../roadmap/1.x/community.md#how-to-give-credit) |

6.2 covers the release notes with credits, moving the `1` and `1.10` tags, closing the superseded PRs and commenting on #16.

### After 1.11

#### 7. Deprecation and outreach

| ID | Issue title | Labels | Blocked by | Resolves | Plan |
|---|---|---|---|---|---|
| 7.1 | build(image): publish deprecation images for the old tags | enhancement, area:image | 6.1, 6.2 | — | [review.md](../../roadmap/1.x/review.md#deprecation-images-for-the-old-tags) |
| 7.2 | chore(outreach): send upgrade PRs to the main upstream users | enhancement, area:operations | 6.2 | — | [review.md](../../roadmap/1.x/review.md#about-archiving-the-old-tags) |

## Rules

Follow these rules for every issue in this plan, together with the plan for the issue's `area:` label.

### Scope

1. **Stay in [GOAL.md](../../GOAL.md).** If a change is not in scope, stop and open an issue to discuss it.
2. **No breaking changes in 1.11.** A user who installs 1.11 with the same values as before gets the same behaviour: the same port, paths, environment variables, message, page fields, Service type, `rewritePath` default and value names. There are only two exceptions. The page shows the real architecture. The image runs as the numeric user `1000`, which is the same UID as the old `node` user. If a change needs the `breaking-change` label, it goes to 2.0.
3. **Only amd64 and arm64.** Do not add other platforms.

### Process

4. **Start only on issues in Ready** on the board. Agents also need the `agent` label. Move the issue to In Progress when you start.
5. **Read this plan and the area plan first.** If the work shows that a plan is wrong, update the plan in the same PR, and update the `updated` date.
6. **Follow the [conventions](../../../AGENTS.md#conventions)** for issues, branches, commits, PRs and verification:
   - Create the branch from the issue: `gh issue develop <n> --base release-1.11 --name <type>/<n>-<slug> --checkout`.
   - Commit titles are conventional commits. Commit bodies are a short paragraph and at most three bullets. Do not reference issues. Sign every commit. Agents add a `Co-Authored-By:` trailer.
   - Open the PR against `release-1.11`. Ask the maintainer to link it to the issue in the Development section, because there is no API for this.
   - Merge with a merge commit. Never squash or rebase.
7. **Tests go with the fix that they prove.** For example, the 2.1 PR adds I1–I3, and the 4.1 PR adds E7.
8. **Keep the epic body up to date.** When you create a sub-issue, add it under its workstream heading in the same step.
9. **Human review** is necessary for anything labelled `security` or `breaking-change`. Agents never merge these.
10. **Public, one-way actions need the maintainer's approval first.** These include pushing or moving image tags, publishing a release, closing community issues and PRs, and commenting on them. The exception: when the work that resolves a community item merges, close it without asking, as AGENTS.md describes (decided 2026-10-28).

### Supply chain

11. **Pin every GitHub Action to a full commit SHA**, with the version in a comment. Never reference `aquasecurity/trivy-action` or `setup-trivy` by tag.
12. **Give every workflow a least-privilege `permissions:` block.**
13. **Verify every download against its published checksum**, and pin base images by digest.

### Credit

14. **Add `Co-authored-by:` trailers when a commit carries forward a contributor's idea or code.** The trailers are listed in [community.md](../../roadmap/1.x/community.md#how-to-give-credit):

    | ID | Credit |
    |---|---|
    | 2.1 | @Alestrix (#35), @chazapis (numeric user, #46), @NikolaiThingnesLeira (#45) |
    | 2.3 | @hotspoons (#38) |
    | 2.4, 3.2 | @MrRoundRobin (#40), @chazapis (#46) |
    | 4.2, 4.5 | @frayos (#31) |
    | 4.4 | @STRRL (#29) |

### Writing

15. **Use simple, direct language** in the style of ASD-STE100 for issues, PRs, comments and docs.

## Validation

An issue is complete only when every check below that applies to it passes, and the results are in the verification comment on the issue. Test the failure paths too: when a check is about something failing, make it fail on purpose and record the result.

### Every issue

- Each acceptance criterion is checked, and the [verification comment](../../../AGENTS.md#verify-then-record) records the result and the evidence. Criteria that were not checked stay unticked, with the reason.
- `git log` on the branch shows only conventional commit titles, signed commits, no issue references and the correct trailers.
- The PR targets `release-1.11`, has the issue's labels and milestone, and follows the PR body format.

### No behaviour change

This check applies to 2.x, 4.1 and 4.2. Save the output from `release-1.11` before the change, then compare it with the output after the change:

- `helm template hello-kubernetes deploy/helm/hello-kubernetes` with the default values. The only differences are the planned additions, such as the `securityContext`.
- The same render with the old `ingress.configured=true`, `ingress.pathPrefix` and `ingress.rewritePath` values. The output matches the new top-level values.
- The page HTML for the default settings, and for each `MESSAGE`, `PORT`, `RENDER_PATH_PREFIX` and `HANDLER_PATH_PREFIX` setting. The only differences are the architecture, the version, and the relative asset URLs when `RENDER_PATH_PREFIX` is not set (2.3, #38).
- The log lines at `LOG_LEVEL=info` and `debug`. They have the same fields, or the PR records the change.

### By workstream

| Workstream | Checks |
|---|---|
| 1. Foundations | `gh label list` shows the 15 labels and no removed labels. The board has the five statuses and the workflow settings from operations.md. The issue forms apply their labels. The PR issue check fails on a PR whose branch has no open issue, and passes when the branch has one. |
| 2. Image and app | `docker build` works from the lockfile on amd64 and arm64. Image tests I1–I7 pass. Trivy finds no fixable HIGH or CRITICAL findings. `docker run --platform linux/arm64` shows `linux/arm64` on the page, and `linux/amd64` shows `linux/amd64`. E1–E4, E7 and E11 pass on kind. |
| 3. CI and publishing | Every `uses:` line is pinned to a 40-character SHA. Every workflow has a `permissions:` block. The scan fails on an image with a known fixable finding, and a wrong checksum stops the Trivy install. A publish to a test tag gives a manifest list with amd64 and arm64 (`docker buildx imagetools inspect`), with SBOM and provenance attached. A failed e2e job blocks the publish. |
| 4. Chart and deployment | `helm lint` and `helm template` pass under Helm 4 in the devcontainer and Helm 3 in CI. `values.schema.json` rejects a wrong type and an unknown value. The scenarios for the issue pass on kind and k3d. The pods run in a namespace with restricted Pod Security. `kubectl apply -f` of the release YAML works on kind. Every command in the changed docs runs with no prompts, and gives the result the doc describes (E15). |
| 5. Website | The site builds in CI and deploys to GitHub Pages under `/hello-kubernetes/`. There are no broken internal links. Each link in `llms.txt` points to raw markdown at the release tag, and each link resolves. The config builder output installs on kind. |
| 6. Release | All 1.11 sub-issues are Done. The arm64 e2e job passes with the default chart, and no e2e scenario has an `EXPECTED_FAILURE` marker. After the merge into `main`, the 10 old Trivy alerts are closed by the scan on `main`, and Trivy in the scan workflow is the newest release that meets the 7-day cooldown. The daily scan on `main` runs the new workflow, which stops the daily failure of the old one (the workflow was re-enabled on 2026-10-29). After the merge into `main`, the issue forms, the security link, the PR template, `SECURITY.md` and the PR labels workflow work (from #59), and Dependabot runs for each ecosystem with no config errors (from #73). The release notes are grouped by label and include the credits. `paulbouwer/hello-kubernetes:1` and `:1.10` point at the 1.11.0 digest. The release asset URL works with `kubectl apply`. |
| 7. After 1.11 | Each deprecation image passes the checks in [review.md](../../roadmap/1.x/review.md#deprecation-images-for-the-old-tags): `/` returns 200, the original message text is present, and the probes pass on kind. The original image stays reachable under the `-original` tag. |

## Epic body

Use this text for the epic issue. It follows the [issue conventions](../../../AGENTS.md#conventions): Summary, Scope and Acceptance criteria, with the work listed by workstream between Scope and Acceptance criteria.

When a sub-issue exists, replace its line with `- #NN`, on its own list line, so that GitHub shows the issue's title and state.

````markdown
## Summary

hello-kubernetes 1.x is out of date. The image is on end-of-life Node 16 and Alpine 3.13, it is published for amd64 only, the vulnerability scan is disabled, the chart has no secure defaults, and the community issues and PRs have waited for years.

This epic brings 1.x up to date in 1.11.0: a patched amd64 and arm64 image, a secure chart that can create an Ingress or an HTTPRoute, tests on real clusters, current docs and a website. People who use the defaults see no change in behaviour. After the release, the old image tags get deprecation warnings, and the main upstream users are told about the upgrade.

- **Plan** (intent, decisions, rules and validation): [`.project/work/2026-10-26-roadmap-1x/plan.md`](https://github.com/paulbouwer/hello-kubernetes/blob/release-1.11/.project/work/2026-10-26-roadmap-1x/plan.md)
- **Why and how**: [`.project/roadmap/1.x/`](https://github.com/paulbouwer/hello-kubernetes/tree/release-1.11/.project/roadmap/1.x)

The work is in workstreams. Each work issue is a sub-issue of this epic and is listed under its workstream below. The IDs are replaced with issue numbers as the issues are created.

## Scope

All of the 1.x roadmap. Breaking chart changes wait for 2.0.

## 1.11

### 1. Foundations
- 1.1 chore(repo): set up the labels, board statuses and board workflows
- 1.2 chore(repo): add AGENTS.md, CONTRIBUTING.md, templates, labeler, release notes config and the PR issue check
- 1.3 chore(triage): label the open items and close the off-topic PRs
- 1.4 chore(deps): add Dependabot and CodeQL

### 2. Image and app
- 2.1 fix(image): move to node:24-alpine with a lockfile and a numeric non-root user
- 2.2 chore(app): upgrade express, pino-http and express-handlebars
- 2.3 fix(app): load assets correctly when RENDER_PATH_PREFIX is not set
- 2.4 feat(app): show the image architecture from the runtime
- 2.5 test(e2e): add the e2e harness and the first kind scenarios
- 2.6 test(image): add the image tests

### 3. CI and publishing
- 3.1 ci(scan): rebuild the vulnerability scan so it fails on fixable findings
- 3.2 ci(publish): publish amd64 and arm64 images to Docker Hub and GHCR
- 3.3 ci(e2e): run the image and e2e tests on amd64 and arm64
- 3.4 fix(ci): find the PR's issue the same way in the labels workflow and the issue check

### 4. Chart and deployment
- 4.1 fix(chart): add secure defaults and fix the chart bugs
- 4.2 feat(chart): create an Ingress or an HTTPRoute from the chart
- 4.3 feat(chart): add values.schema.json
- 4.4 ci(release): publish the rendered YAML and the OCI chart with each release
- 4.5 docs(deploy): rewrite the deployment docs for Helm, kubectl and Kustomize
- 4.6 test(e2e): add k3d, Ingress and Gateway API scenarios

### 5. Website
- 5.1 feat(site): scaffold the Starlight site and publish it to GitHub Pages
- 5.2 feat(site): style the docs and add llms.txt
- 5.3 feat(site): add the landing page
- 5.4 feat(site): add the config builder and the live preview

### 6. Release
- 6.1 docs(project): write and approve the deprecation plan for the old tags
- 6.2 chore(release): release 1.11.0

## After 1.11

### 7. Deprecation and outreach
- 7.1 build(image): publish deprecation images for the old tags
- 7.2 chore(outreach): send upgrade PRs to the main upstream users

## Acceptance criteria

- [ ] The work plan, with the decisions, rules and validation, is in the repo, and the roadmap notes agree with it.
- [ ] Every work item is a sub-issue of this epic, listed under its workstream.
- [ ] 1.11.0 is released, and all 1.11 sub-issues are done.
- [ ] People who use the defaults see no change in behaviour in 1.11.0, apart from the correct architecture.
- [ ] The old image tags show a deprecation warning, and the main upstream users have been told about the upgrade.

````

## Open

- **Before automatic PR labelling goes live in 6.2:** tracked as 3.4 (#95), from the [workstream 1 review](workstream-01-review.md#finding-to-address).
- **Before arm64 CI:** placed in 3.3 and 4.1, and a release gate in 6.2, from the [workstream 2 review](workstream-02-review.md#follow-up-before-arm64-ci).
- **The due date** of `v1.11` (2026-10-30) is not realistic for 24 issues. Look at it again when the issues exist.
- **An image override with the old tags breaks with the new chart defaults.** The 1.10.1 and older images run as the non-numeric `USER node`, so `runAsNonRoot: true` rejects them (#35). Document this in the 4.1 release notes, or set `runAsUser: 1000` in the chart so that the kubelet can verify it. Decide in 4.1.
- **After the 1.x work:** enforce "only the owner creates labels" with a workflow that removes or reports labels that are not in `.github/labels.sh`, and a CODEOWNERS entry for the script. See the [labels and board plan](../2026-10-26-labels-and-board/plan.md#open).
