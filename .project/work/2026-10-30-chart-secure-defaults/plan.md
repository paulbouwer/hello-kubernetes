---
title: Chart secure defaults
description: Give the chart secure defaults that meet the restricted Pod Security Standard, fix its bugs, and run the e2e tests on arm64.
type: plan
status: active
areas: [deploy, ci]
issues: [113]
created: 2026-10-30
updated: 2026-10-30
---

# Chart secure defaults

## Intent

The chart had no `securityContext`, so a namespace that enforces the restricted Pod Security Standard rejected its pods (#35). It pinned pods to amd64 nodes, did not quote the message, so a `"` broke the YAML, still installed the 1.10 image, and had an empty `NOTES.txt`. This work fixes all of them, and proves the default chart on arm64 with native arm64 e2e jobs.

This is work item 4.1 in the [1.x work plan](../2026-10-26-roadmap-1x/plan.md#4-chart-and-deployment). It includes the arm64 e2e follow-up from the [workstream 2 review](../2026-10-26-roadmap-1x/workstream-02-review.md), and one minor issue from the [workstream 3 review](../2026-10-26-roadmap-1x/workstream-03-review.md#minor-issues).

## Decisions

Made on 2026-10-30 (maintainer).

| Decision | Result |
|---|---|
| Old image tags | The pod `securityContext` sets `runAsUser: 1000` and `runAsGroup: 1000`. In the 1.10.1 and older images, the user `node` is 1000, so they also pass `runAsNonRoot`. This is what we told the #35 reporter. The release notes need no warning. |
| `appVersion` | `"1.11.0"`, the exact tag, so one chart version always installs the same image. Until 6.2 publishes that tag, the default image doesn't exist; the e2e tests set their own image. |
| e2e job names | `e2e (<cluster>, <arch>)` for kind and k3d on amd64 and arm64. They replace `e2e (kind)` and `e2e (k3d)` in the ruleset, just before the merge. |
| Helm version | Helm 4 only. Helm 3 is near the end of its security fixes, and the devcontainer and CI already use Helm 4. The plan's "Helm 3 in CI" check is dropped, and the docs say Helm 4. |
| `/tmp` | The root filesystem is read-only, so the chart mounts an `emptyDir` at `/tmp`, as image test I7 does with `--tmpfs /tmp`. |
| Chart `version` | Stays `1.0.0`. The chart is not published yet; 4.4 sets its version when it publishes it. |

## Tracking

- **Issue:** [#113](https://github.com/paulbouwer/hello-kubernetes/issues/113), a sub-issue of epic [#54](https://github.com/paulbouwer/hello-kubernetes/issues/54). Resolves the chart half of #35.
- **Branch:** `fix/113-chart-secure-defaults`, from `release-1.11`.
- **Labels, milestone, assignee:** `bug`, `area:deploy`, `area:ci`, `v1.11`, @paulbouwer.

## Validation

| Check | How |
|---|---|
| Restricted Pod Security | E7 passes on kind and k3d, with no expected-failure marker: no warnings, and `id -u` prints 1000. |
| Quoting | E3 passes: a message with `<b>`, `&` and `"` installs and shows escaped. `helm template` with a `"` in `pathPrefix` renders valid YAML. |
| arm64 | The four `e2e (<cluster>, <arch>)` jobs pass in CI. On arm64, E2 checks the page shows `linux/arm64`. |
| Old image | The 1.10.1 image, with `USER node`, installs in a restricted namespace with the chart defaults, runs as user 1000 and serves the page. |
| Chart | `helm lint` passes under Helm 4. `NOTES.txt` renders for LoadBalancer, ClusterIP, NodePort and an ingress. The default image is `paulbouwer/hello-kubernetes:1.11.0`. |
| Image tests | `make test-image` passes with the `mktemp` error file. |
