---
title: Asset paths
description: Make the asset URLs relative when no render prefix is set, treat a prefix of only slashes as no prefix, and add proxy tests that prove it.
type: plan
status: done
areas: [app]
issues: [81]
created: 2026-10-28
updated: 2026-10-28
---

# Asset paths

## Intent

With no `RENDER_PATH_PREFIX`, the page asked for `/css/main.css` and `/images/kubernetes.png` at the domain root. Behind a proxy that serves the app under a path and strips it, those requests failed, so the page had no styles and no logo (#38, reported by @hotspoons). The chart always sets `RENDER_PATH_PREFIX` when it rewrites paths, so this affected people who run the image without the chart. This work fixes it without changing the page for anyone who sets a prefix.

This is work item 2.3 in the [1.x work plan](../2026-10-26-roadmap-1x/plan.md#2-image-and-app). The decision is in [community.md](../../roadmap/1.x/community.md#incorporate-in-spirit).

## Decisions

Made on 2026-10-28.

| Decision | Result |
|---|---|
| The fix | Relative asset URLs (`css/main.css`) when no render prefix is set. With a prefix, the URLs stay absolute (`/app/css/main.css`) and don't change. This is @hotspoons' suggestion, in another form. |
| Trailing slash | Relative URLs need the page URL to end in `/`. At `/hello`, the browser still asks for `/css/main.css`, as before. This is documented in `src/app/README.md`, not handled in the app, because the app can't know the external path. @ngaffa's NGINX workaround on #38 adds that redirect at the proxy. |
| A prefix of only `/` | It made the asset URLs `//css/main.css`, which a browser reads as another host. `normalisePrefix()` now treats a prefix of only slashes as no prefix, for both variables. |
| `HANDLER_PATH_PREFIX` without `RENDER_PATH_PREFIX` | Also fixed. The app served its assets under the handler prefix, but the page asked for them at the root. The relative URLs now resolve under the prefix. |
| Proof | `test/proxy/run.sh` (`make test-proxy`), in its own script, with an NGINX proxy pinned to `nginx:1.30.5-alpine` by digest. That build was pushed on 2026-09-26, which meets the 7-day cooldown. The current `stable-alpine` build was 6 days old. |
| No behaviour change | The relative asset URLs with no prefix are a third allowed difference in the 1.x plan, with the architecture and the version. |

## Tracking

- **Issue:** [#81](https://github.com/paulbouwer/hello-kubernetes/issues/81), a sub-issue of epic [#54](https://github.com/paulbouwer/hello-kubernetes/issues/54), blocked by #77. Resolves #38.
- **Branch:** `fix/81-asset-paths`, from `release-1.11`.
- **Labels, milestone, assignee:** `bug`, `area:app`, `v1.11`, @paulbouwer.
- **Credit:** a `Co-authored-by` trailer for @hotspoons. Thanks to @ngaffa in the 1.11.0 release notes.

## Work

1. `src/app/server.js`: `normalisePrefix()`, and an `assetPathPrefix` that is `/app/` with a render prefix and empty without one.
2. `src/app/views/layouts/main.handlebars`: build the asset URLs from `assetPathPrefix`.
3. `test/proxy/run.sh` and `make test-proxy`.
4. Docs: `src/app/README.md`, testing.md, and the 1.x plan.

## Validation

| Check | How |
|---|---|
| The fix | `make test-proxy` on the fixed image: P1, P2 and P3 pass. |
| The test proves it | The same script on the 2.2 image: P1 fails (the assets return 404 at the domain root) and P3 fails (`//css/main.css`). P2 passes, because a set prefix was never broken. |
| No other change | Against the 2.2 image, for the defaults, `MESSAGE`, `PORT`, each prefix and `LOG_LEVEL=debug`: with `RENDER_PATH_PREFIX` set, the page is the same. Without it, only the two asset URLs differ. The log fields and line counts are the same in every case. |
| Image tests | I1 to I3 still pass. |

## Open

- **Close #38** with a link to the PR after the merge, as promised in our comment there.
