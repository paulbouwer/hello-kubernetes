---
title: Reused local clusters
description: Check a reused cluster's Kubernetes version and image IDs, and make make e2e-clean stop cloud-provider-kind.
type: plan
status: done
areas: [ci]
issues: [133]
created: 2026-10-30
updated: 2026-10-30
---

# Reused local clusters

## Intent

Since 4.7, the e2e tests reuse a running local cluster. The [workstream 4 review](../2026-10-26-roadmap-1x/workstream-04-review.md#minor-issues) found three gaps in that: a reused cluster's Kubernetes version wasn't checked, so `make e2e-kind-oldest` could test 1.37; the k3d image check compared names, so an older image with the same tag could hide a failed import; and `make e2e-clean` left `cloud-provider-kind` running. CI starts fresh clusters, so only local runs were affected.

This is work item 4.9 in the [1.x work plan](../2026-10-26-roadmap-1x/plan.md#4-chart-and-deployment).

## Decisions

| Decision | Result |
|---|---|
| Version | `check_cluster_version` in `cluster.sh` compares the server version with the node image's, for `run.sh` and `local.sh`. A mismatch stops the run, and says to run `make cluster-clean`. |
| Image ID | `image_on_k3d_nodes` compares Docker's image ID with each node's. With Docker's containerd image store, the ID is the manifest digest, which `ctr` shows; with the classic store, it is the config digest, which `crictl` shows. Either matches. |
| Clean | `make e2e-clean` runs `test/e2e/local.sh clean`, like `make cluster-clean`. |

## Tracking

- **Issue:** [#133](https://github.com/paulbouwer/hello-kubernetes/issues/133), a sub-issue of epic [#54](https://github.com/paulbouwer/hello-kubernetes/issues/54).
- **Branch:** `test/133-reused-local-clusters`, from `release-1.11`.
- **Labels, milestone, assignee:** `enhancement`, `area:ci`, `v1.11`, @paulbouwer.

## Validation

| Check | How |
|---|---|
| Version | With a 1.37 cluster from `make cluster-kind`, `make e2e-kind-oldest` stopped: "runs Kubernetes v1.37.0, not v1.35.8". `run.sh kind` reused it and passed. |
| Image ID | On a `make cluster-k3d` cluster, the check passed after the import, failed after a newer build was tagged `hello-kubernetes:e2e`, and passed again after `load_image`. |
| Clean | `make e2e-clean` deleted both clusters, stopped `cloud-provider-kind`, and left no files. |
| CI | All required checks pass. |
