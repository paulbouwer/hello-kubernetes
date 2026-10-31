---
title: Bundled font
description: Bundle the Ubuntu font and its licence in the image, so the app's page makes no request to Google Fonts.
type: plan
status: done
areas: [image]
issues: [137]
created: 2026-10-31
updated: 2026-10-31
---

# Bundled font

## Intent

The app's page loaded the Ubuntu font from Google Fonts. Every visitor's browser contacted Google, and in clusters with no internet access the font failed and the page fell back to a default font. The site's live preview (5.5) would have made the same request. This work bundles the font in the image.

This is work item 5.1 in the [1.x work plan](../2026-10-26-roadmap-1x/plan.md#5-website), from the [website plan](../../roadmap/1.x/site.md#live-preview).

## Decisions

| Decision | Result |
|---|---|
| Source | `@fontsource/ubuntu` 5.3.0 (released 2026-07-19), checked against its npm integrity. |
| Bundled, not a dependency | The weight-300 `.woff2` files are copied into `src/app/static/fonts/ubuntu/`, with `SOURCE.md` giving the version, each file's SHA-256 and how to update them. A few static files that rarely change don't need a runtime npm package in the image. |
| Licence | The Ubuntu Font Licence 1.0 allows bundling and redistributing the unmodified fonts, with the copyright notice and the licence. `LICENCE.txt` ships next to the files, in the repo and the image. |
| Subsets | One file per character subset, each with its `unicode-range` in `main.css`, as Google Fonts serves them, so a browser downloads only what a page uses. |
| Paths | `url('../fonts/ubuntu/…')` relative to `css/main.css`, so the font loads under any path prefix. |

## Tracking

- **Issue:** [#137](https://github.com/paulbouwer/hello-kubernetes/issues/137), a sub-issue of epic [#54](https://github.com/paulbouwer/hello-kubernetes/issues/54).
- **Branch:** `fix/137-bundled-font`, from `release-1.11`.
- **Labels, milestone, assignee:** `bug`, `area:image`, `v1.11`, @paulbouwer.

## Validation

| Check | How |
|---|---|
| No external requests | In Chromium (Playwright), the page made 4 requests, all to the app: the page, the stylesheet, the logo and the Latin font. |
| Font | The browser loaded Ubuntu 300 for the Latin range, and a screenshot shows the page as before. |
| I8 | Passes, and fails with the Google Fonts link or an `@import` put back. |
| Proxy | P1–P3 load all 6 font references through the proxy, and fail on a font path resolved from the wrong place. |
