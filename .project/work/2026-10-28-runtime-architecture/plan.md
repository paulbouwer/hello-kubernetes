---
title: Runtime architecture
description: Show the image architecture from the running Node binary, mapped to OCI names, and remove info.json.
type: plan
status: done
areas: [app]
issues: [83]
created: 2026-10-28
updated: 2026-10-28
---

# Runtime architecture

## Intent

The page footer showed the image's architecture from `src/app/info.json`, which was hard-coded to `linux/amd64`. When 3.2 publishes arm64 images, an arm64 pod would have shown the wrong architecture. This work reads the architecture from the running Node binary, so the page can't be wrong, and needs no build step.

This is work item 2.4 in the [1.x work plan](../2026-10-26-roadmap-1x/plan.md#2-image-and-app), and takes PR #40's approach. The reasons are in [image.md](../../roadmap/1.x/image.md#supported-amd64-and-arm64).

It also records how agents close community items when the work that resolves them merges, as the maintainer decided on 2026-10-28.

## Decisions

Made on 2026-10-28.

| Decision | Result |
|---|---|
| Source | `process.platform` and `process.arch`. They are fixed when the Node binary is built, so an amd64 image under emulation on an arm64 node shows `linux/amd64`, which is correct for the image. `os.machine()` would show the host. |
| Mapping | Node's names that differ from OCI names: `x64` → `amd64`, `ia32` → `386`, `ppc64` → `ppc64le` (Node reports little-endian ppc64 as `ppc64`). Other names (`arm64`, `s390x`, `riscv64`, `arm`) are shown as they are. |
| ARM variant | Not shown. Node 24 has no 32-bit Arm build, so `arm/v7` can't occur in our images. |
| Override variable | None. The page must show the real architecture. |
| `info.json` | Removed, with its `COPY` in the Dockerfile and its row in `src/app/README.md`. |
| Proof | Image test I5a: the real architecture against `docker inspect`, and a simulated `process.arch` (`test/image/fake-arch.js`, preloaded with `NODE_OPTIONS=--require`) for the mapping. The helper is test-only. The per-platform check I5 comes in 2.6, and real arm64 runs in 3.3. |
| Community items | AGENTS.md and rule 10 of the 1.x plan now say that agents close a community issue or PR without asking when the work that resolves it merges, and what the comment says. |

## Tracking

- **Issue:** [#83](https://github.com/paulbouwer/hello-kubernetes/issues/83), a sub-issue of epic [#54](https://github.com/paulbouwer/hello-kubernetes/issues/54), blocked by #77.
- **Branch:** `feat/83-runtime-architecture`, from `release-1.11`.
- **Labels, milestone, assignee:** `enhancement`, `area:app`, `v1.11`, @paulbouwer.
- **Credit:** `Co-authored-by` trailers for @MrRoundRobin (#40) and @chazapis (#46). PRs #40 and #46 stay open until 3.2 merges.

## Validation

| Check | How |
|---|---|
| The mapping | I5a passes on the new image. On the 2.3 image, it fails: every simulated architecture shows `linux/amd64`. |
| No `info.json` | The image's `/usr/src/app` has no `info.json`, and `server.js` doesn't read it. |
| No behaviour change on amd64 | Against the 2.3 image, for the defaults, `MESSAGE`, `PORT`, each prefix and `LOG_LEVEL=debug`: the same page byte for byte, and the same log fields and line counts. The footer still shows `linux/amd64`. |
| Other tests | I1 to I3 and the proxy tests P1 to P3 still pass. |

## Open

- **PRs #40 and #46** are closed with a link when 3.2 merges, as promised in our comments there.
