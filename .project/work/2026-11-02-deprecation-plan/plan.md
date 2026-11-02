---
title: Deprecation plan
description: Write the deprecation plan for the old image tags, and build and test the warning images without publishing them.
type: plan
status: in-progress
areas: [image, operations]
issues: [154]
created: 2026-11-02
updated: 2026-11-02
---

# Deprecation plan

## Intent

Write the plan for warning everyone on an old image tag, and get the maintainer's sign-off before anything is pushed. The maintainer asked for the scripts and the page assets to be built and tested now, so the sign-off covers real, tested images; 7.1 only runs them, after 1.11.0 ships.

This is work item 6.1 in the [1.x work plan](../2026-10-26-roadmap-1x/plan.md#6-release). The plan is [deprecation.md](../../roadmap/1.x/deprecation.md).

## Decisions

Made with the maintainer on 2026-11-02; the full list is in [deprecation.md](../../roadmap/1.x/deprecation.md#decisions).

| Decision | Result |
|---|---|
| Split | 6.1: the plan, the assets and the scripts, built and tested without publishing. 7.1: publish and announce, after 1.11.0. |
| Tags | All 13 old tags at once, right after 1.11.0. `1.10` stays with 1.10.1 and gets the warning; `1`, `1.11` and `1.11.0` point at 1.11.0. This corrects the earlier plan, which moved `1.10` to 1.11.0. |
| Originals | Kept as `<tag>-original` Docker tags for 4 weeks, the rollback window. No git tags. |
| Removal | The warning images stay; their removal is reviewed after 6 months. |
| GHCR | Recommended from 1.11; the chart's default in 2.0. |
| Build | A layer on each original, pinned by digest. `patch.js` runs with the image's own Node, from 6.10 to 16.10, so it uses only Node 6 syntax. |
| Page families | 1.0–1.3 write their HTML in `server.js`; 1.4–1.10.1 use a Handlebars layout. The banner goes straight after `<body>` in either. |
| Notice | A `prestart` script, so `npm start`, the command of every old image, prints it first, with no change to the app. |
| Test | The new page, with the banner taken out, must equal the original page byte for byte (D2). |
| Publish | Not run in 6.1: it changes public tags, and Claude Code's auto mode refused to run even its refusal paths. The guards are reviewed by reading the script. |

## Tracking

- **Issue:** [#154](https://github.com/paulbouwer/hello-kubernetes/issues/154), a sub-issue of epic [#54](https://github.com/paulbouwer/hello-kubernetes/issues/54).
- **Branch:** `docs/154-deprecation-plan`, from `release-1.11`.
- **Labels, milestone, assignee:** `documentation`, `area:operations`, `v1.11`, @paulbouwer.

## Validation

| Check | How |
|---|---|
| Build | `deprecation/deprecate.sh build`: all 13 images. |
| Checks | `deprecation/deprecate.sh test`: D1–D4 and K1 pass for all 13. |
| Failure path | A patch that also changed the page failed D2. |
| Look | Screenshots of 1.0, 1.3, 1.5 and 1.10.1, and the startup log of 1.5. |
| Sign-off | The maintainer approves deprecation.md, on the issue and in its sign-off section. |
