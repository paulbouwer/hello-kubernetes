---
title: Site scaffold
description: Scaffold the website with Astro, Starlight and Preact, its identity and code block theme, the Pages workflow, and the required site checks.
type: plan
status: done
areas: [site, ci]
issues: [139]
created: 2026-10-31
updated: 2026-10-31
---

# Site scaffold

## Intent

Set up the website that will hold the user docs, as agreed in the [website plan](../../roadmap/1.x/site.md): the Astro and Starlight project in `site/`, the hello-kubernetes identity and the code block style, a Pages workflow that builds every PR and deploys from `main`, and a required check that keeps the site's links, browser behaviour and accessibility sound. The rest of the pages come in 5.3.

This is work item 5.2 in the [1.x work plan](../2026-10-26-roadmap-1x/plan.md#5-website).

## Decisions

Made on 2026-10-31, many of them with the maintainer from screenshots.

| Decision | Result |
|---|---|
| Versions | Astro 7.4.2, Starlight 0.42.7, Preact 11.0.2, `@astrojs/preact` 6.1.1, `starlight-links-validator` 0.27.0, the four `@fontsource` packages 5.3.0, `@astrojs/check` 0.9.12 with TypeScript 6.0.3 (it doesn't support 7), `@playwright/test` 1.64.1 and `@axe-core/playwright` 4.14.0. Installed with `--before=2026-10-25T00:00:00Z`, so every package, with its dependencies, is at least 7 days old. |
| Code blocks | microsandbox's look in our colours, settled over several rounds: a dark blue-grey background (the navy tried first was too strong), a blue border, one header height, a bare copy icon in the header, lone titles in light blue with no underline, and a quieter output frame. A small Expressive Code plugin titles command blocks "Terminal" and marks `output` blocks. |
| Layout | A 1000px page column, 24px section headings, small previous and next links across the column, no pill buttons, and no "Edit page" links. |
| Sidebar icons | Starlight has none for pages, so `src/components/Sidebar.astro` and `SidebarSublist.astro` are Starlight's own (MIT), with an icon from the page's `sidebar.attrs.data-icon`. |
| Footer | Report an issue, Contribute, and Font licences, on a small page listing each font's licence. |
| CSP | **Dropped.** Astro's policy blocked 26 of Starlight's inline scripts and 260 inline styles on code tokens. Keeping it would have needed our own hashing step and `'unsafe-inline'` for style attributes, which the plan ruled out. The checks still fail on any request to another site. |
| Accessibility | axe fails on serious and critical problems. One exception: `label-content-name-mismatch` on Starlight's search button, which shows "Search Ctrl K" and is named "Search". |
| Playwright | Its official image, pinned by digest in the `Makefile`, for `make site-test`, CI and `make screenshot`. |
| Landing page | A temporary one, until 5.6. |

## Tracking

- **Issue:** [#139](https://github.com/paulbouwer/hello-kubernetes/issues/139), a sub-issue of epic [#54](https://github.com/paulbouwer/hello-kubernetes/issues/54).
- **Branch:** `feat/139-site-scaffold`, from `release-1.11`.
- **Labels, milestone, assignee:** `enhancement`, `area:site`, `area:ci`, `v1.11`, @paulbouwer.

## Validation

| Check | How |
|---|---|
| Build | `make site`: `astro check` with no errors, and 5 pages built, with every internal link valid. |
| Browser | `make site-test`: every page, light and dark, loads with no console error and no request to another site, and has no serious or critical axe problem. |
| The checks catch problems | A Google Fonts stylesheet failed every page. An image with no alt text failed as critical. A relative link failed the build. |
| Copy | Every copy button is on top and clickable, and copying a code group gives its commands, one per line. |
| Screenshot | `make screenshot` wrote the app's page from k3d, with a real namespace, pod and node. |
| Look | Reviewed by the maintainer from the dev server and screenshots. |
| CI | The `site` job passes on the PR. |
