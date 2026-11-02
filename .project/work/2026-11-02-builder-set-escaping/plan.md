---
title: Builder --set escaping
description: Escape the config builder's --set values for Helm's parser, test messages with special characters, and give the Overview table headers.
type: plan
status: done
areas: [site]
issues: [152]
created: 2026-11-02
updated: 2026-11-02
---

# Builder --set escaping

## Intent

Fix the defect the [workstream 5 review](../2026-10-26-roadmap-1x/workstream-05-review.md#finding-to-address) found: the config builder's `helm install` and `helm template` commands broke or changed messages with commas, backslashes or braces, because Helm's `--set` parser reads them as syntax even with `--set-string`. The drift tests passed because none of their messages had those characters.

This is work item 5.7 in the [1.x work plan](../2026-10-26-roadmap-1x/plan.md#5-website). The maintainer placed it in workstream 5, before 6.2, because it is a defect in shipped work (2026-11-02). The Overview table's empty headers, a minor issue from the same review, are fixed here too.

## Decisions

| Decision | Result |
|---|---|
| Escaping | `\`, `,`, `{` and `}` get a backslash in every `--set-string` value, before the shell quoting. Brackets, quotes, `=` and `.` need none in a value: probes with Helm 4 kept them as typed. |
| Tests first | The drift tests got the messages first, and failed on the old builder: `Hello, Kubernetes!` and `{hello}` failed, `C:\demo` became `C:demo`, and a mixed message broke the parser. S2 compares the rendered `MESSAGE` with the text typed, so a silent change fails too. |
| Failures | S2 and S3 now report a failing `helm template` for that case and go on, rather than stopping the run. |
| Docs | The With Helm page says which characters need a backslash, with an example that was run, and points to a values file and the builder. |
| Overview | The table's headers are "Part" and "What it is"; axe no longer reports `empty-table-header`. |

## Tracking

- **Issue:** [#152](https://github.com/paulbouwer/hello-kubernetes/issues/152), a sub-issue of epic [#54](https://github.com/paulbouwer/hello-kubernetes/issues/54).
- **Branch:** `fix/152-builder-set-escaping`, from `release-1.11`.
- **Labels, milestone, assignee:** `bug`, `area:site`, `v1.11`, @paulbouwer.

## Validation

| Check | How |
|---|---|
| Drift | `make site-drift`: S2 and S3 pass for 8 messages with special characters, which failed before the fix, and for every other case. |
| Browser | `make site-test`: 111 checks, with no `empty-table-header` warning. |
| Docs example | `helm template` with `--set-string message='Hello\, Kubernetes!'` renders `Hello, Kubernetes!`. |
| CI | The required checks pass on the PR. |
