---
title: Landing page
description: Add the landing page, with the headline, the command, a mock-up that chips change, the features, an Open Graph image and structured data.
type: plan
status: done
areas: [site]
issues: [148]
created: 2026-11-01
updated: 2026-11-02
---

# Landing page

## Intent

Give the site a front page in Herdr's layout, as the [website plan](../../roadmap/1.x/site.md#landing-page) agreed. It should show what hello-kubernetes does in one look, with a command to copy, and keep the first load small.

This is work item 5.6 in the [1.x work plan](../2026-10-26-roadmap-1x/plan.md#5-website), the last in workstream 5.

## Decisions

Made on 2026-11-01. The maintainer chose the command, the header links and the image before the build, and the cosmetic changes after reviewing it.

| Decision | Result |
|---|---|
| The command | Helm only, with no `kubectl | Helm` switch (first built as rounded rectangles, not pills). "All the ways to deploy" leads to kubectl and Kustomize. |
| Header links | Docs and Config builder, on the landing page only, through a `SocialIcons` override. |
| Open Graph image | `make og-image` draws `site/public/og.png` with the pinned Playwright image, from the real preview; the PNG is committed. Every page links it, with `twitter:card` set to `summary_large_image`. |
| Chips | Default, Your message, Behind an Ingress, and 4 pods across nodes. Default shows the quick start's Helm command; the others show the builder's, in a brief form. The drift tests run every chip. The address bar shows `hello.example.com`, reserved for documentation. |
| Mock-up | The browser and the terminal are the same width. The terminal shows `kubectl get pods -o custom-columns=…`, which fits and shows each pod's node, in place of `-o wide`; its font scales with the screen, so it never scrolls. The pod that answered is highlighted. |
| Order | The headline, then the chips, then the command, then the mock-up, so the chips stay in place as the command changes length. |
| Features | The headline's two tones: white titles in Archivo, grey text in the body font. Each icon is a large watermark off the box's corner, at 3% over the box. |
| Browser window | One component, `BrowserFrame.tsx`, for the landing page and the config builder, at the maintainer's request, so the preview looks and works the same in both. In the builder, the address follows the host, the port and the path prefix, and the reload button sends another request. |
| Closing | "Get started", with the quick start and config builder buttons, and no command. |
| Size | The chips' commands and terminal output are worked out at build time. The island is 4 KB; the preview's assets load when the mock-up comes into view. |
| Title | Starlight's page title is left out on the landing page, so it has one headline. |
| Structured data | A `SoftwareApplication` with the chart's version, the licence and the repo. No `offers` or price: it is open source, with nothing to buy (maintainer, 2026-11-02). |

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
