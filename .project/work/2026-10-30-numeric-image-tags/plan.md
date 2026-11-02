---
title: Numeric image tags
description: Render numeric image tags as text, so the image name is valid, and test real numeric values.
type: plan
status: done
areas: [deploy]
issues: [131]
created: 2026-10-30
updated: 2026-10-30
---

# Numeric image tags

## Intent

The schema lets the image tag be a number (4.3), but the image helper formatted it with `%s`, so `--set deployment.container.image.tag=1` rendered `paulbouwer/hello-kubernetes:%!s(int64=1)`, and `tag: 1.11` in a values file rendered `%!s(float64=1.11)`. Helm accepted both, and the pods could not pull the image. Chart test C14 missed it, because `--set …=1.11` arrives as a string. The [workstream 4 review](../2026-10-26-roadmap-1x/workstream-04-review.md#finding-to-address) found it.

This is work item 4.8 in the [1.x work plan](../2026-10-26-roadmap-1x/plan.md#4-chart-and-deployment).

## Decisions

| Decision | Result |
|---|---|
| Fix | The helper chooses the tag or `appVersion` first, then turns it into text with `toString`. An empty or unset tag still gives `appVersion`. |
| Tests | C14 renders the integer `1` from `--set`, the number `1.11` from a values file, a string, a pre-release, an empty and an unset tag, and checks the image, `CONTAINER_IMAGE` and that no `%!` appears. |
| Docs | Quote a version tag in a values file, because YAML reads `1.10` as the number 1.1. |

## Tracking

- **Issue:** [#131](https://github.com/paulbouwer/hello-kubernetes/issues/131), a sub-issue of epic [#54](https://github.com/paulbouwer/hello-kubernetes/issues/54).
- **Branch:** `fix/131-numeric-image-tags`, from `release-1.11`.
- **Labels, milestone, assignee:** `bug`, `area:deploy`, `v1.11`, @paulbouwer.

## Validation

| Check | How |
|---|---|
| Fix | `helm template` renders `:1`, `:1.11`, `:1.11.0-rc.1` and, for an empty or unset tag, `:1.11.0`, in the image and in `CONTAINER_IMAGE`. |
| Test | C14 passes with the fix, and fails with the old helper on the integer and the values-file number. |
| Cluster | A release with `--set deployment.container.image.tag=1` starts its pods on kind, with the image loaded under that tag. |
