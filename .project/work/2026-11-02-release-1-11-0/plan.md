---
title: Release 1.11.0
description: Prepare and release hello-kubernetes 1.11.0, its chart, its release file and its website, then check everything that is live.
type: plan
status: in-progress
areas: [operations, ci, site, image]
issues: [156]
created: 2026-11-02
updated: 2026-11-02
---

# Release 1.11.0

## Intent

Release 1.11.0, the first release in five years, and check that everything people will use works where they'll use it: the images on both registries, the chart on GHCR and Artifact Hub, the release file, and the website. The exit criteria are the 6. Release row of the [1.x work plan](../2026-10-26-roadmap-1x/plan.md#by-workstream).

This is work item 6.2. The 7.1 deprecation images follow right after it, as [deprecation.md](../../roadmap/1.x/deprecation.md) sets out.

## Stages

| Stage | What | Who |
|---|---|---|
| A. Before the release | E09 and E15 from the workstream 5 review, the app's version, the GHCR recommendation, the README screenshot, and the release notes' draft. A PR to `release-1.11`. | builder |
| B1 | Turn on GitHub Pages, with GitHub Actions as the source. | maintainer |
| B2 | Merge `release-1.11` into `main` with a PR. The site deploys, and the scans, forms, labels and Dependabot run on `main`. | builder, after the maintainer's go-ahead |
| B3 | Tag `v1.11.0` on `main`. The publish workflow pushes the images and the chart, signs them, and creates a draft release with `hello-kubernetes.yaml`. | builder, after the maintainer's go-ahead |
| B4 | Add the hand-written notes ([release-notes.md](release-notes.md)) above the generated ones, and publish the release. | maintainer |
| B5 | Check what's live: tags, `verify-published`, attestations, Artifact Hub, the release file, the chart upgrade from 1.10.1, the website. Close #23. | builder |
| Then | 7.1: the deprecation images and the announcement. | builder, after the maintainer's go-ahead |

## Decisions

| Decision | Result |
|---|---|
| E09 | Waits up to 60 seconds for a second pod to answer, instead of sending a fixed 20 requests. It passed in 2 requests; with every answer forced to one pod, it failed after 215 requests in 60 seconds. |
| E15 | Snapshots Deployments, Services, ServiceAccounts, Ingresses, HTTPRoutes, Middlewares and namespaces before and after each flow. A guide that didn't delete its namespace failed, naming the flow and the namespace and ServiceAccount it left. |
| Version | `src/app/package.json` and its lockfile are 1.11.0, matching the chart, so the publish workflow's version check passes. |
| GHCR | The Container image page, the Overview and the README name GHCR first, as recommended; the chart's default stays Docker Hub in 1.x. |
| Screenshot | `make screenshot` on k3d, with the local build loaded as `paulbouwer/hello-kubernetes:1.11.0`. The page is real, but the node line's kernel, the maintainer's own machine's, is shown as `Linux 7.x` (maintainer, 2026-11-02). `site/scripts/app-screenshot.mjs` makes that one change, and fails if the line isn't there. |

## Tracking

- **Issue:** [#156](https://github.com/paulbouwer/hello-kubernetes/issues/156), a sub-issue of epic [#54](https://github.com/paulbouwer/hello-kubernetes/issues/54).
- **Branch:** `chore/156-release-prep` for stage A, from `release-1.11`.
- **Labels, milestone, assignee:** `enhancement`, `area:operations`, `v1.11`, @paulbouwer.

## Validation

The 6. Release row of the 1.x work plan, checked in B5 and recorded in the verification comment on #156.
