---
title: Deprecation images
description: Publish the deprecation images for the old tags, and announce them.
type: plan
status: done
areas: [image, operations]
issues: [165]
created: 2026-11-03
updated: 2026-11-03
---

# Deprecation images

## Intent

Run the signed-off [deprecation plan](../../roadmap/1.x/deprecation.md): give every old tag its warning image, keep each original as `<tag>-original`, and announce it the same day.

This is work item 7.1, under the follow-up epic [#166](https://github.com/paulbouwer/hello-kubernetes/issues/166), in the `1.11.follow-ups` milestone.

## Decisions

Made with the maintainer on 2026-11-03.

| Decision | Result |
|---|---|
| Milestone | `1.11.follow-ups`, for the work after 1.11.0. The 1.x epic, #54, stays in `v1.11`, and closed with 1.11.0 delivered; its "After 1.11" work moved to the new epic #166. |
| Publish | The maintainer ran `deprecate.sh publish --yes`, logged in to Docker Hub, because it pushes as them. |
| Docker Hub overview | The maintainer pastes a banner that builder drafted. |
| Announcement | Pinned issue #167, the README note, the 1.11.0 release notes and the Docker Hub overview, all on 2026-11-03. |

## Tracking

- **Issue:** [#165](https://github.com/paulbouwer/hello-kubernetes/issues/165), a sub-issue of epic [#166](https://github.com/paulbouwer/hello-kubernetes/issues/166).
- **Branch:** `build/165-deprecation-images`, from `release-1.11`.
- **Labels, milestone, assignee:** `enhancement`, `area:image`, `1.11.follow-ups`, @paulbouwer.

## Validation

| Check | How |
|---|---|
| Before | All 13 digests unchanged on Docker Hub; all 65 checks passed on images rebuilt that day. |
| Published | Every old tag has the deprecation label; every `-original` tag points to the original manifest, and the original digest still pulls; `1`, `1.11` and `1.11.0` are unchanged. |
| Live | `1.5`, pulled fresh, shows the banner and the notice; `1.5-original` shows neither. |
| Announced | #167 is pinned; the README, the release notes and the Docker Hub overview link to it. |
