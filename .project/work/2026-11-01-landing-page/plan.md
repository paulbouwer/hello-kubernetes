---
title: Landing page
description: Add the landing page, with the headline, the command, a mock-up that chips change, the features, an Open Graph image and structured data.
type: plan
status: done
areas: [site]
issues: [148]
created: 2026-11-01
updated: 2026-11-01
---

# Landing page

## Intent

Give the site a front page in Herdr's layout, as the [website plan](../../roadmap/1.x/site.md#landing-page) agreed. It should show what hello-kubernetes does in one look, with a command to copy, and keep the first load small.

This is work item 5.6 in the [1.x work plan](../2026-10-26-roadmap-1x/plan.md#5-website), the last in workstream 5.

## Decisions

Made on 2026-11-01. The maintainer chose the first three.

| Decision | Result |
|---|---|
| The command switch | `kubectl` and `Helm` as rounded rectangles, not pills, so the no-pills rule holds everywhere. |
| Header links | Docs and Config builder, on the landing page only, through a `SocialIcons` override. |
| Open Graph image | `make og-image` draws `site/public/og.png` with the pinned Playwright image, from the real preview; the PNG is committed. Every page links it, with `twitter:card` set to `summary_large_image`. |
| Chips | Default, Your message, Behind an Ingress, and 4 pods across nodes. Default shows the quick start's commands; the others show the builder's Helm command in a brief form. The drift tests run every chip. |
| Terminal | `kubectl get pods -o custom-columns=…`, which fits and shows each pod's node, in place of `-o wide`. The pod that answered is highlighted. |
| Size | The chips' commands and terminal output are worked out at build time. The island is 4 KB; the preview's assets load when the mock-up comes into view. |
| Title | Starlight's page title is left out on the landing page, so it has one headline. |
| Structured data | A `SoftwareApplication` with the chart's version, the licence and the repo. |

## Tracking

- **Issue:** [#148](https://github.com/paulbouwer/hello-kubernetes/issues/148), a sub-issue of epic [#54](https://github.com/paulbouwer/hello-kubernetes/issues/54).
- **Branch:** `feat/148-landing-page`, from `release-1.11`.
- **Labels, milestone, assignee:** `enhancement`, `area:site`, `v1.11`, @paulbouwer.

## Validation

| Check | How |
|---|---|
| Browser | `make site-test`: 110 checks, including `tests/landing.spec.ts`, three runs in a row. |
| Drift | `make site-drift`: every chip passes S2 and S3. |
| Look | Screenshots in dark and light, desktop and phone, and of the Open Graph image. |
| CI | The `site` job passes on the PR. |
