---
title: Chart Ingress and HTTPRoute
description: Let the chart create an Ingress or a Gateway API HTTPRoute, with top-level pathPrefix and rewritePath, and keep the old names working.
type: plan
status: done
areas: [deploy, ci]
issues: [115]
created: 2026-10-30
updated: 2026-10-30
---

# Chart Ingress and HTTPRoute

## Intent

The chart never created an Ingress or a route. `ingress.configured` only set the app's prefix variables, and users wrote their own Ingress, from an example that broke when Kubernetes removed `networking.k8s.io/v1beta1` (#31). This work lets the chart create a `networking.k8s.io/v1` Ingress or a Gateway API `HTTPRoute`, as designed in [deploy.md](../../roadmap/1.x/deploy.md#exposing-the-app).

This is work item 4.2 in the [1.x work plan](../2026-10-26-roadmap-1x/plan.md#4-chart-and-deployment). The e2e scenarios on real controllers are 4.6, the schema is 4.3, and the docs and worked examples are 4.5. #31 closes with 4.5.

## Decisions

Made on 2026-10-30 (maintainer).

| Decision | Result |
|---|---|
| Old names | `pathPrefix` wins over the old `ingress.pathPrefix`, which still needs `ingress.configured`, as before. A `false` `rewritePath` in the old or the new name wins, because both default to `true`. |
| Prefix form | `app/hello`, `/app/hello` and `/app/hello/` all become `/app/hello`. `/` alone means no prefix. The app already normalises its prefix variables the same way. |
| Deprecation | The install notes list any old `ingress.*` names in use, and the new names that replace them. The old names are removed in 2.0. |
| Service type | Stays `LoadBalancer` by default in 1.x. An Ingress or HTTPRoute routes to the Service by name, so `ClusterIP` is enough; a `LoadBalancer` still works but adds an address that bypasses them. The notes suggest `ClusterIP` when a route is enabled. |
| Tests | `test/chart/run.sh` renders the chart and checks it (C1–C11), in each e2e job and with `make test-chart`. A live check behind k3d's Traefik covers the four ways of exposing the app. |
| HTTPRoute with no Gateway | The install fails with a clear message, because a route with no `parentRefs` attaches to nothing. |

## Tracking

- **Issue:** [#115](https://github.com/paulbouwer/hello-kubernetes/issues/115), a sub-issue of epic [#54](https://github.com/paulbouwer/hello-kubernetes/issues/54).
- **Branch:** `feat/115-chart-ingress-httproute`, from `release-1.11`.
- **Labels, milestone, assignee:** `enhancement`, `area:deploy`, `area:ci`, `v1.11`, @paulbouwer.

## Validation

| Check | How |
|---|---|
| Chart tests | `test/chart/run.sh`: C1–C11 pass. Breaking the old-name rule, the `URLRewrite` filter or the prefix normalising each fails at least one scenario. |
| Old names | For the old values, the Deployment differs from the previous chart only in the normalised prefix (`hello` to `/hello`), a trailing slash on the probe path, and quoting. |
| Live, k3d with Traefik 3.6 | Ingress with `rewritePath=false`; Ingress with `rewritePath=true` and a Traefik `stripPrefix` middleware; HTTPRoute with the `URLRewrite` filter; HTTPRoute without it. Each serves the page and its stylesheet under the prefix. Both routes are `Accepted` with `ResolvedRefs`. |
| Default chart | The e2e scenarios pass on kind and k3d. |
