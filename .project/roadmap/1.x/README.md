---
title: 1.x roadmap
description: Index of the 1.x plan, with reading order, open decisions and known issues not yet in a plan.
type: index
status: active
created: 2026-10-23
updated: 2026-10-25
---

# 1.x roadmap

The plan for bringing hello-kubernetes 1.x up to date, written in October 2026 and updated as decisions are made. Every change is measured against the project's scope in [GOAL.md](../../GOAL.md).

These notes explain *why* and *how*. *What ships when* lives in GitHub milestones and issues (the `v1.11` milestone, with issues from #50 on). Issues and milestones link to the section of the note they implement, rather than the notes listing release contents.

## Reading order

| File | Area label | What it covers |
|---|---|---|
| [review.md](review.md) | — | Start here. What was found in October 2026 (end-of-life base image, disabled scanner, old actions), the seven fixes with effort and impact, who uses the old image tags, and the deprecation images for them |
| [image.md](image.md) | `area:image`, `area:app` | Node over Bun, base image (`node:24-alpine`, later distroless), debugging with `kubectl debug`, amd64/arm64 only, `info.json`, vulnerability scanning and the Trivy incident |
| [deploy.md](deploy.md) | `area:deploy` | Helm as the single source, rendered release YAML, Kustomize patches, chart-created Ingress and HTTPRoute with NGINX and Traefik examples, the values reference |
| [testing.md](testing.md) | `area:ci` | Image tests and e2e scenarios on kind (NGINX) and k3d (Traefik), Gateway API, CI matrix, running locally |
| [operations.md](operations.md) | `area:operations` | Labels and what each drives, the project board, release branches, conventions for issues, branches, commits, PRs and verification, rules for agents, supporting files, `gh label` setup |
| [site.md](site.md) | `area:site` | GitHub Pages site with Astro + Starlight, landing page, config builder, `llms.txt` and agent experience |
| [community.md](community.md) | — | Triage of open issues and PRs, what to merge, incorporate or close, and how to credit contributors |

## Open decisions

| Decision | Where it's discussed |
|---|---|
| Make no-rewrite (`rewritePath: false`) the chart default | [deploy.md](deploy.md#path-prefixes-and-rewriting) |
| Move `pathPrefix` and `rewritePath` to the top level of the values | [deploy.md](deploy.md#proposed-values) |
| Default Service type: keep `LoadBalancer` or switch to `ClusterIP` | [deploy.md](deploy.md#proposed-values) |
| Detect the architecture at runtime (PR #40's approach) or have CI write `info.json` (current plan in GOAL.md) | [community.md](community.md#incorporate-in-spirit), [image.md](image.md#supported-amd64-and-arm64) |
| Hold the breaking chart changes for 2.0, so users migrate once | [rewrite.md](../2.x/rewrite.md#delivering-it-in-stages) |

When a decision is made, update the note it belongs to and remove it from this table.

## Known issues not yet in a plan

- **`nodeSelector` pins pods to amd64.** `values.yaml` defaults to `kubernetes.io/arch: amd64`, so arm64 pods would never be scheduled even after arm64 images ship. Keep only `kubernetes.io/os: linux`. Belongs in [deploy.md](deploy.md) and review fix 4 or 6. Found in [rewrite.md](../2.x/rewrite.md#a-1x-bug-found-along-the-way).
- **Review fix 3 predates the Trivy incident.** It says to use `trivy-action` pinned; [image.md](image.md#trivy-installed-safely) refines that to a checksum-verified release or an action pinned to a commit SHA.

## Related

- [GOAL.md](../../GOAL.md): scope for the whole project.
- [2.x/rewrite.md](../2.x/rewrite.md): thought exercise for a Go rewrite in 2.0, including the proposed `/healthz` endpoint.
