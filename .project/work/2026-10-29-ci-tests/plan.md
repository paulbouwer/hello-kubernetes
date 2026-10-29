---
title: CI tests
description: Run the image, proxy and e2e tests on every PR as required checks, on native amd64 and arm64, from one pinned tool table, and harden the test harness.
type: plan
status: done
areas: [ci]
issues: [98]
created: 2026-10-29
updated: 2026-10-29
---

# CI tests

## Intent

The image, proxy and e2e tests only ran when someone ran them locally, and the arm64 image had never been built or run. This work runs them on every PR as required checks, so a change that breaks the image, the app behind a proxy, or the chart on a cluster can't merge, and publishing (3.2) only ships tested code. It also closes the three harness gaps from the [workstream 2 review](../2026-10-26-roadmap-1x/workstream-02-review.md).

This is work item 3.3 in the [1.x work plan](../2026-10-26-roadmap-1x/plan.md#3-ci-and-publishing). The design is in [testing.md](../../roadmap/1.x/testing.md#ci).

## Decisions

Made on 2026-10-29.

| Decision | Result |
|---|---|
| Jobs | `image-tests (amd64)` and `image-tests (arm64)` on native runners (`ubuntu-latest`, `ubuntu-24.04-arm`): build the image, then the image and proxy tests. `e2e (kind)` and `e2e (k3d)` on amd64. No QEMU: each job builds and tests its own architecture. |
| arm64 e2e | Comes with 4.1, when the chart stops pinning pods to amd64 (workstream 2 review). |
| Required checks | All four jobs are added to the ruleset right after the merge (maintainer). |
| Diagnostics | In the job log only. No artifact (maintainer). |
| Superseded runs | A new push to a PR cancels that PR's older runs. Runs on branches are never cancelled (maintainer). |
| Tool versions | Defined once, in `test/ci/install-tools.sh`: Trivy 0.76.1, kind 0.33.0, k3d 5.9.0, Helm 4.3.1, kubectl 1.37.1, each with a SHA-256 for amd64 and arm64 that was checked against the project's published checksums. All were published at least 7 days before. The scan workflow (3.1) now uses the same table. The devcontainer still installs the latest releases; pinning it to this table is #99 (maintainer). |
| Expected failures | A scenario with `EXPECTED_FAILURE` must also set `EXPECTED_ERROR`, a pattern for the error it expects. It is XFAIL only when its output matches; any other failure is a FAIL. E3 expects `YAML parse error`, E7 `would violate PodSecurity`. |
| Cluster deletion | A failed deletion prints the error and fails the run. |
| Docker errors | `serve_page` prints Docker's error when a container doesn't start, and the container's logs when the page doesn't load. |
| `--pull never` | Found while testing: `docker run --platform linux/arm64` with an amd64-only local image pulled the 2021 image from Docker Hub, and the local tag then pointed to it, so later tests checked the wrong image. Every test container in the image and proxy tests now runs with `--pull never`. This also corrected the cause recorded in 3.1 (#94), and a note was added to #90. |

## Tracking

- **Issue:** [#98](https://github.com/paulbouwer/hello-kubernetes/issues/98), a sub-issue of epic [#54](https://github.com/paulbouwer/hello-kubernetes/issues/54), blocked by #87 and #90.
- **Branch:** `ci/98-ci-tests`, from `release-1.11`.
- **Labels, milestone, assignee:** `enhancement`, `area:ci`, `v1.11`, @paulbouwer.
- **Follow-up:** [#99](https://github.com/paulbouwer/hello-kubernetes/issues/99), the devcontainer installs from the same table.

## Validation

| Check | How |
|---|---|
| CI jobs | All four jobs pass on the PR for this work. The arm64 job's I5 shows `linux/arm64`. |
| Required checks | After the merge, the ruleset lists the four jobs, and a test PR that fails one of them is `BLOCKED`. |
| Tool table | The installer installs all five tools at the pinned versions. A wrong SHA-256 stops it, and an unknown tool name exits 2. |
| Expected failures | A normal run: E3 and E7 are XFAIL. With E3's `EXPECTED_ERROR` set to text that doesn't appear: FAIL, and the run exits 1. |
| Cluster deletion | A `kind` stand-in whose `delete` fails: the run reports it and exits 1, and `make e2e-clean` removes the cluster. |
| Docker errors | A platform the image doesn't have: Docker's error is shown. An app that exits at startup: its log line is shown. |
| `--pull never` | The same mismatched-platform test fails I5 with Docker's error, and the local tag still points to the local build. |
