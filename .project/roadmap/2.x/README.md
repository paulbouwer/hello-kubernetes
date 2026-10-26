---
title: 2.x roadmap
description: Index of ideas for 2.0, with open decisions and the work that starts in 1.x.
type: index
status: active
created: 2026-10-23
updated: 2026-10-26
---

# 2.x roadmap

Ideas for hello-kubernetes 2.0. Nothing here is a plan of record yet: these are thought exercises, measured against the project's scope in [GOAL.md](../../GOAL.md). When an idea is accepted, GOAL.md and the affected notes are updated, and the work is tracked in GitHub milestones and issues that link back here.

## Notes

| File | What it covers |
|---|---|
| [rewrite.md](rewrite.md) | Rewriting the app in Go (standard library only) to support `linux/arm/v7` and `linux/riscv64` without changing what it does: the from-scratch design, a proposed `/healthz` endpoint, which architectures earn their place, the changes every 1.x note would need, and staged delivery |

## Open decisions

| Decision | Where it's discussed |
|---|---|
| Go over Rust | [rewrite.md](rewrite.md#language-go-standard-library-only) |
| Add `/healthz` to the scope in GOAL.md | [rewrite.md](rewrite.md#health-endpoint) |
| Architectures: arm/v7 and riscv64 in, ppc64le and s390x out | [rewrite.md](rewrite.md#architectures) |
| How long 1.x keeps getting security rebuilds after 2.0 | [rewrite.md](rewrite.md#delivering-it-in-stages) |

When a decision is made, update the note it belongs to (and GOAL.md if scope changes) and remove it from this table.

Decided on 2026-10-26: the breaking chart changes wait for 2.0, so users migrate once. See [rewrite.md](rewrite.md#delivering-it-in-stages) and the [1.x work plan](../../work/2026-10-26-roadmap-1x/plan.md#decisions).

## Work that starts in 1.x

Stage 0 of [rewrite.md](rewrite.md#delivering-it-in-stages) happens in the 1.x series and is useful whether or not 2.0 goes ahead:

- the black-box e2e suite in [testing.md](../1.x/testing.md), with the image under test as a parameter
- a written behaviour contract for the app in `src/app/README.md`
- the non-breaking chart additions in [deploy.md](../1.x/deploy.md)
- the `nodeSelector` fix listed in the [1.x README](../1.x/README.md#known-issues-now-in-the-work-plan).

## Related

- [GOAL.md](../../GOAL.md): scope for the whole project, including the possible 2.0 goal.
- [1.x README](../1.x/README.md): the current plan.
