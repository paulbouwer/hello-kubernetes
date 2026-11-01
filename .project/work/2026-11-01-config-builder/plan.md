---
title: Config builder and live preview
description: Add the config builder, with Helm and Kustomize output, and a live preview of the app's page, both checked against the chart and the app in CI.
type: plan
status: done
areas: [site, ci]
issues: [146]
created: 2026-11-01
updated: 2026-11-01
---

# Config builder and live preview

## Intent

Give people the commands and files for the options they change, and show them the page their pods will serve, as the [website plan](../../roadmap/1.x/site.md#config-builder) agreed. Both must stay true to the chart and the app, so CI checks them against both.

This is work item 5.5 in the [1.x work plan](../2026-10-26-roadmap-1x/plan.md#5-website). The landing page (5.6) reuses the preview.

## Decisions

Made on 2026-11-01. The maintainer agreed the design before the build.

| Decision | Result |
|---|---|
| Options | Release name and namespace; message and replicas; Service type and port; Service only, Ingress (class, host) or Gateway (name, namespace, host name); path prefix and rewriting; registry and tag. Labels and help text come from the schema. |
| Output | `helm install` with `--set` flags (`--set-string` for text), `values.yaml` with its install command, Kustomize on the pinned release file, and `helm template`. Each has a copy button. |
| Layout | The form on the left; the preview and the output on the right, sticky, so both stay in view while you fill in the form. Stacked on a phone. |
| Preview | The app's own templates and CSS, rendered with the app's Handlebars version, trimmed as express-handlebars does, in an `iframe` with an empty `sandbox` and `srcdoc`, with the CSS, font and logo inlined. |
| Shared code | `site/src/lib/builder.mjs` and `preview.mjs` are plain JavaScript, so the drift test runs them in Node. |
| Drift tests | `site/tests/drift.mjs` (`make site-drift`), in the `site` job: S1 preview vs app container, S2 builder vs `helm template`, S3 Kustomize vs `helm template`. |
| axe | Legacy mode with iframes off. In its default mode, axe waits for the sandboxed frame, where no script runs, until the test times out. |
| Markdown copy | The builder becomes a note pointing agents to the values reference and the schema. |
| Dependencies | `handlebars` 4.7.10 (the app's) and `yaml` 2.9.1, installed with `--before=2026-10-26T00:00:00Z`; `npm audit signatures` passed. |
| Size | The builder's script is about 430 KB, mostly the inlined fonts. 5.6 should load the preview's assets only when it shows the preview. |

## Tracking

- **Issue:** [#146](https://github.com/paulbouwer/hello-kubernetes/issues/146), a sub-issue of epic [#54](https://github.com/paulbouwer/hello-kubernetes/issues/54).
- **Branch:** `feat/146-config-builder`, from `release-1.11`.
- **Labels, milestone, assignee:** `enhancement`, `area:site`, `v1.11`, @paulbouwer.

## Validation

| Check | How |
|---|---|
| Drift | `make site-drift`: 19 tests pass. A changed default message failed S1; a wrong probe path failed S3, naming the field. |
| Browser | `make site-test`: 104 checks, including `tests/builder.spec.ts`. An image with no alt text still failed axe, and a logo that wasn't inlined failed the builder test. |
| Look | Screenshots in light, dark and phone width. |
| CI | The `site` job passes on the PR. |
