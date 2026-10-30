---
title: E2E scenarios
description: Add the Ingress, Gateway API, cluster, version and docs e2e scenarios on kind and k3d.
type: plan
status: active
areas: [ci, deploy]
issues: [123]
created: 2026-10-30
updated: 2026-10-30
---

# E2E scenarios

## Intent

The e2e tests covered the default chart, a custom message and port, restricted Pod Security and uninstalling (E1–E4, E7, E11). They didn't test what 1.11 adds: the chart's Ingress and HTTPRoute on real controllers, a `LoadBalancer`, pods across nodes, the release file, upgrades, older Kubernetes versions, or the docs. This work adds those scenarios on kind and k3d, on amd64 and arm64, as designed in [testing.md](../../roadmap/1.x/testing.md#end-to-end-scenarios).

This is work item 4.6 in the [1.x work plan](../2026-10-26-roadmap-1x/plan.md#4-chart-and-deployment).

## Decisions

Made on 2026-10-30 (maintainer).

| Decision | Result |
|---|---|
| PRs | One issue, three PRs: **A** Ingress and Gateway (E5, E6, E16, E17, E18), **B** cluster behaviour (E8, E9, E10, E12), **C** versions and docs (E13, E15). |
| Controllers | kind: the F5 NGINX Ingress Controller and NGINX Gateway Fabric, so both controller families in the docs are tested. k3d: k3s's built-in Traefik, for the Ingress and the Gateway. |
| Cluster setup | `test/e2e/cluster.sh` creates and sets up each cluster, for `run.sh` and for 4.7's local clusters. |
| Oldest Kubernetes | 1.35, the oldest of the three minor versions upstream supports. E13 runs on kind amd64, as a required check (C). |
| E15 | Code blocks marked `` ```bash e2e `` run in order, with the OCI chart, the image and the release URL swapped for the local ones (C). |

## Findings

From PR A, on kind with the NGINX Ingress Controller 5.7.0:

- It rejects an Ingress with no host (`spec.rules[0].host: Required value`), and allows one Ingress per host (`All hosts are taken by other resources`). Traefik and the Gateway API have neither limit. The docs now say so, and the scenarios give each release its own host.
- `nginx.org/rewrites: "serviceName=hello-kubernetes-<release> rewrite=/"` works with the chart's path, which has no trailing slash: the page and its assets load. The Ingress guide now has this NGINX rewrite example.

## Tracking

- **Issue:** [#123](https://github.com/paulbouwer/hello-kubernetes/issues/123), a sub-issue of epic [#54](https://github.com/paulbouwer/hello-kubernetes/issues/54).
- **Branches:** `test/123-ingress-gateway-e2e` (A), then one branch each for B and C, from `release-1.11`.
- **Labels, milestone, assignee:** `enhancement`, `area:ci`, `v1.11`, @paulbouwer.

## Validation

| Check | How |
|---|---|
| A | E5, E6, E16, E17 and E18 pass with the earlier scenarios on kind and k3d locally (amd64), and in the four CI e2e jobs (amd64 and arm64). Without the rewrite annotation, E5 fails with a 404. |
| B | E8, E9, E10 and E12 pass on kind and k3d, on amd64 and arm64. |
| C | E13 passes on Kubernetes 1.35. E15 runs the marked commands from the README and the guides. |
