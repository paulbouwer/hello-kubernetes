---
title: E2E harness
description: Add an e2e harness that runs the chart on local kind and k3d clusters with the image built from the working tree, and the first scenarios E1 to E4, E7 and E11 on both.
type: plan
status: done
areas: [ci]
issues: [87]
created: 2026-10-28
updated: 2026-10-28
---

# E2E harness

## Intent

Most of the 1.x fixes can only be proven on a real cluster: the numeric non-root user, the probes, the path prefixes and the architecture on the page. This work adds a harness that creates a local kind or k3d cluster, loads the image built from the working tree, installs the chart, and checks the result with `kubectl`, `helm` and `curl`. It adds the first six scenarios from [testing.md](../../roadmap/1.x/testing.md#end-to-end-scenarios), and runs all of them on both clusters.

This is work item 2.5 in the [1.x work plan](../2026-10-26-roadmap-1x/plan.md#2-image-and-app). 3.3 runs it in CI, and 4.6 adds the Ingress and Gateway API scenarios.

## Decisions

Made on 2026-10-28.

| Decision | Result |
|---|---|
| Clusters | kind and k3d, both in 2.5, with every scenario on both (the maintainer's decision). k3d moved from 4.6, which is now Ingress and Gateway API only. For these six scenarios the clusters behave the same. k3s adds most value in 4.6: Traefik, ServiceLB and its Gateway provider. |
| Versions | Both run Kubernetes 1.37, pinned by digest in `run.sh`: `kindest/node:v1.37.0` (kind v0.33's default, pushed 2026-08-26) and `rancher/k3s:v1.37.1-k3s1` (pushed 2026-09-30). k3d's default k3s is 1.35, so it's set explicitly. Both images cover amd64 and arm64. |
| Topology | 1 control plane or server and 2 workers or agents, so pods spread across nodes. No port mappings yet: 4.6 adds them, on host ports other than 8080, which `make run` uses. |
| Image under test | `make e2e-*` builds `hello-kubernetes:e2e` from the working tree and loads it into the cluster. The chart is installed with that repository and tag, and `pullPolicy: Never`, so no registry image can stand in for it. |
| Known failures | E3 and E7 fail until 4.1 fixes the chart. They set `EXPECTED_FAILURE`, so the harness reports them as XFAIL and the run passes. If one passes, it reports XPASS and fails the run, so the marker is removed in 4.1. |
| Cluster lifecycle | `run.sh` creates the cluster and deletes it at the end. `KEEP_CLUSTER=1` keeps it, and keeps a failed scenario's namespace. An existing cluster is reused and not deleted. The kubeconfig is kept in `$TMPDIR`, apart from `~/.kube/config`. `make e2e-clean` deletes both clusters and their kubeconfigs. |
| Scenario layout | One file per scenario in `test/e2e/scenarios/`, with a `scenario` function, in its own namespace `hk-eNN`. `lib.sh` has the helpers: `install`, `wait_ready`, `page`, `contains`, `not_contains`, `page_field` and `dump_diagnostics`. |
| E11 release name | `uninstall-check`, so that the cluster-wide check for leftovers can't see the other scenarios' `hello-world` releases while their namespaces are deleted. |

## Tracking

- **Issue:** [#87](https://github.com/paulbouwer/hello-kubernetes/issues/87), a sub-issue of epic [#54](https://github.com/paulbouwer/hello-kubernetes/issues/54).
- **Branch:** `test/87-e2e-harness`, from `release-1.11`.
- **Labels, milestone, assignee:** `enhancement`, `area:ci`, `v1.11`, @paulbouwer.

## Work

1. `test/e2e/kind-config.yaml`, `k3d-config.yaml`, `lib.sh`, `run.sh`, and the scenarios E1 to E4, E7 and E11.
2. `Makefile`: `e2e-kind`, `e2e-k3d`, `e2e` and `e2e-clean`.
3. Update the 1.x plan (2.5 and 4.6), the epic body, and testing.md.

## Validation

| Check | How |
|---|---|
| Both clusters | `make e2e`: on kind and on k3d, E1, E2, E4 and E11 pass, E3 and E7 are XFAIL, and the run passes. Both clusters are deleted at the end. |
| XFAIL reasons | E3 fails with a YAML parse error from the unquoted message. E7 fails because restricted Pod Security rejects the pods (`would violate PodSecurity "restricted"`, 0/2 replicas). |
| A failing scenario | A broken image, built from the e2e image to exit at once: E1 fails, prints the pods in `CrashLoopBackOff` with their events, keeps its namespace with `KEEP_CLUSTER=1`, and the run exits 1. |
| XPASS | A temporary `EXPECTED_FAILURE` on E4, which passes: the run reports XPASS and exits 1. |
| Reuse and clean-up | A second run reuses the kept cluster. `make e2e-clean` deletes it and its kubeconfig. |
| Bad input | A missing image, or a cluster type other than `kind` or `k3d`, exits with 2 and says why. |

## Open

- **3.3 must load a single-platform image into kind.** `kind load docker-image` failed for a multi-platform image (`node:24-alpine`): containerd looked for content of the other platforms, which wasn't pulled. Build with `docker buildx build --load` for one platform in each CI job.
- **arm64 needs 4.1 first.** The chart's default `nodeSelector` pins pods to `kubernetes.io/arch: amd64`, so on arm64 runners (3.3) every scenario fails until 4.1 removes it.
- **4.1 removes the `EXPECTED_FAILURE` markers** from E3 and E7.
