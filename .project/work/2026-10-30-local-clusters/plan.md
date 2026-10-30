---
title: Local clusters
description: Start a local kind or k3d cluster, set up as the e2e tests set it up, to try the deployment docs.
type: plan
status: done
areas: [operations]
issues: [127]
created: 2026-10-30
updated: 2026-10-30
---

# Local clusters

## Intent

Trying the deployment docs needed a cluster with an Ingress controller, a Gateway and the image, which took many steps to set up by hand. The e2e tests already set up exactly that in `test/e2e/cluster.sh` (4.6). This work adds `make` targets that start the same cluster and keep it, so anyone can try the docs on it. The maintainer asked for it during 4.6.

This is work item 4.7 in the [1.x work plan](../2026-10-26-roadmap-1x/plan.md#4-chart-and-deployment).

## Decisions

Made on 2026-10-30.

| Decision | Result |
|---|---|
| Targets | `make cluster-kind`, `make cluster-k3d` and `make cluster-clean`, through `test/e2e/local.sh`, which uses `cluster.sh`. |
| Cluster names and ports | The same as the e2e tests, so the e2e targets reuse a running local cluster instead of clashing with it over the ports. |
| Image | The local build is loaded as the chart's default image, `paulbouwer/hello-kubernetes:<appVersion>`, so the docs' commands use it before that version is published. The output and the docs say that, in that cluster, the tag is the local build. |
| Ports | 18080, 18081 and 18082 are in `forwardPorts` in `devcontainer.json`, so VS Code forwards them to the host. |

## Tracking

- **Issue:** [#127](https://github.com/paulbouwer/hello-kubernetes/issues/127), a sub-issue of epic [#54](https://github.com/paulbouwer/hello-kubernetes/issues/54).
- **Branch:** `feat/127-local-clusters`, from `release-1.11`.
- **Labels, milestone, assignee:** `enhancement`, `area:operations`, `v1.11`, @paulbouwer.

## Validation

| Check | How |
|---|---|
| kind | `make cluster-kind`, then the printed example: the Ingress served the page, running the chart's default image. An HTTPRoute through `hk-gateway` and a `LoadBalancer` Service with a `cloud-provider-kind` address also served it. |
| k3d | `make cluster-k3d`, then the printed example: the Ingress served the page. |
| Reuse | Running the target again reused the cluster, with one `cloud-provider-kind`. `run.sh kind` reused it, passed, and left it running. |
| Clean | `make cluster-clean` deleted both clusters, stopped `cloud-provider-kind`, and removed the kubeconfigs. |
