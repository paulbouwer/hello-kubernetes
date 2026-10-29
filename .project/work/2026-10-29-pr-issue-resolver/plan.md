---
title: PR issue resolver
description: Find the PR's issue with one shared resolver in the issue check and the labels workflow, and fail a PR that points at more than one open issue.
type: plan
status: active
areas: [ci, operations]
issues: [95]
created: 2026-10-29
updated: 2026-10-29
---

# PR issue resolver

## Intent

The PR issue check and the PR labels workflow each found the PR's issue in their own way, so they could pick different issues for one PR. A PR could then pass the check for one issue and get its labels and milestone from another, which could leave out the `security` label that stops an agent from merging it. This work gives both workflows one shared resolver.

This is work item 3.4 in the [1.x work plan](../2026-10-26-roadmap-1x/plan.md#3-ci-and-publishing), from the [workstream 1 review](../2026-10-26-roadmap-1x/workstream-01-review.md#finding-to-address).

## Decisions

Made on 2026-10-29.

| Decision | Result |
|---|---|
| One resolver | `.github/scripts/find-pr-issue.sh PR HEAD_REF`. The candidates are the branch number and the issues linked in the Development section. Only open issues in this repo count: not closed issues, not PRs, not issues in another repo. |
| One issue per PR | A PR belongs to exactly one issue, and one issue can have several PRs. If the valid candidates are two or more different issues, the resolver exits 3, the issue check fails with a message that says so, and the labels workflow copies nothing (maintainer). |
| Write access | `pr-labels.yaml` runs the resolver from the base branch, which `actions/checkout` gets by default in `pull_request_target`. It never checks out the PR's head. |
| Tests | `test/ci/find-pr-issue-test.sh` runs the resolver against a stand-in `gh` with prepared answers, so it covers cases that are hard to set up on GitHub, such as a linked issue in another repo. It also checks that both workflows use the resolver, and that `pr-labels.yaml` doesn't check out the PR's head. It runs in the `workflow-tests` CI job, which becomes a required check (maintainer). |
| Live labels check | The labels workflow runs only from `main`, so its live check is in 6.2. |

## Tracking

- **Issue:** [#95](https://github.com/paulbouwer/hello-kubernetes/issues/95), a sub-issue of epic [#54](https://github.com/paulbouwer/hello-kubernetes/issues/54), blocked by #59.
- **Branch:** `fix/95-pr-issue-resolver`, from `release-1.11`.
- **Labels, milestone, assignee:** `security`, `area:ci`, `v1.11`, @paulbouwer. The maintainer reviews it before the merge.

## Validation

| Check | How |
|---|---|
| Resolver cases | 12 cases pass: an open branch issue; the same issue from the branch and a link; a closed branch issue with an open linked issue; a branch number that is a PR; a linked issue with no branch number; a link to another repo, ignored; another repo's link not shadowing this repo's; no issue; only closed issues; a missing branch number; two different open issues; two different linked open issues. |
| The tests catch bugs | With the repo filter removed from the resolver, 2 cases fail. With a checkout of the PR's head added to `pr-labels.yaml`, the guard fails. |
| Live check | On the PR for this work, `issue-check` passes with the new resolver. A test PR whose branch is named for a closed issue, with an open issue linked, passes on the open issue. With a second open issue linked, it fails with the "more than one" message. |
| Required check | After the merge, `workflow-tests` is added to the ruleset. |
