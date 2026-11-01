---
title: Docs for agents
description: Publish llms.txt, llms-full.txt, a Markdown copy of every page, the chart's schema, a hidden note and a For AI agents page.
type: plan
status: done
areas: [site]
issues: [144]
created: 2026-11-01
updated: 2026-11-01
---

# Docs for agents

## Intent

Make the docs easy for AI agents to use, as the [website plan](../../roadmap/1.x/site.md#agent-experience-ax) agreed. An agent starts from `llms.txt`, opens only the Markdown pages it needs, and checks chart values against the schema.

This is work item 5.4 in the [1.x work plan](../2026-10-26-roadmap-1x/plan.md#5-website).

## Decisions

Made on 2026-11-01.

| Decision | Result |
|---|---|
| Generator | Our own script, `site/scripts/build-markdown.mjs`, run as `postbuild`. `starlight-llms-txt` 0.12.0 was tried: it is maintained, but its `llms.txt` layout is fixed and has no per-page Markdown links, so it can't meet the plan. |
| Converter | unified 11.0.5, rehype-parse 9.0.1, rehype-remark 10.0.1, remark-gfm 4.0.1, remark-stringify 11.0.0 and hast-util-select 6.0.4, as dev dependencies, installed with `--before=2026-10-26T00:00:00Z`. `npm audit signatures` verified every package. |
| Markdown URLs | `/docs/deploy/helm/` has `/docs/deploy/helm.md`. Links between pages point to the `.md` copies. |
| Code blocks | A code group becomes each tab's label in bold, then its block. A file block has `File: <name>` above it, and an output block `Output:`. |
| The diagram | Path prefixes' diagram has a screen-reader-only `: ` after each label, so it reads as "Browser: asks for …" as text and in Markdown. |
| Hidden note | In a `PageTitle` override, with the `hidden` attribute. It names the page's Markdown copy and `llms.txt`. |
| Copy button | "Copy page as Markdown" and "View as Markdown" under each docs page's title. If copying fails, it says to use the link. |
| Link validation | The validator runs before the files exist, so it skips `llms.txt`, `llms-full.txt` and `values.schema.json`; the Playwright checks load them. |
| Site tests | `make site-test` now mounts the whole repo, so the checks can read the chart's version. |

## Tracking

- **Issue:** [#144](https://github.com/paulbouwer/hello-kubernetes/issues/144), a sub-issue of epic [#54](https://github.com/paulbouwer/hello-kubernetes/issues/54).
- **Branch:** `feat/144-llms-txt`, from `release-1.11`.
- **Labels, milestone, assignee:** `enhancement`, `area:site`, `v1.11`, @paulbouwer.

## Validation

| Check | How |
|---|---|
| Files | `make site` writes `llms.txt`, `llms-full.txt`, the schema and 17 Markdown pages. |
| Checks | `make site-test`: 95 checks, including `tests/agents.spec.ts`. |
| Failure paths | A deleted `.md` copy and a `<div>` in another failed four checks, naming the page. |
| CI | The `site` job passes on the PR. |
