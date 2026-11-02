---
title: Workstream 02 review
description: Review of the image and app work, with passing amd64 checks and a chart dependency to make explicit before arm64 CI.
type: review
status: final
areas: [app, image, ci]
created: 2026-10-29
updated: 2026-10-29
agent_harness: GitHub Copilot CLI
agent_harness_version: 1.0.103
agent_model: GPT-6.1 Sol
agent_model_id: gpt-6.1-sol
reviewed_commit: 79083fcefcdccf4c455d81b569b873e53e72f455
---

# Workstream 02 review

## Scope and outcome

Review of workstream 2, Image and app, in the [epic work plan](plan.md#2-image-and-app), covering #75, #77, #81, #83, #85, #87 and #90. This includes the implementation, work package plans and verification comments, including the final body-parser bump on #77. Minor issues were excluded.

**No new major implementation defect was found.** The image and app changes look sound on amd64. The main follow-up is to make the chart dependency explicit before starting arm64 e2e CI. A passing run today is not full release proof: arm64 is still unverified, and two chart scenarios remain expected failures.

No fixes, branches, commits or GitHub changes were made as part of this review.

## What looks sound

- **Image and dependencies:** both build stages use the pinned Node 24 image; `npm ci` uses the committed lockfile; the runtime starts Node directly as `1000:1000`, without npm. The current lockfile includes body-parser 2.4.0, so the earlier HIGH finding on #77 is resolved. A fresh build passed I1-I7 and I5a, including the vulnerability scan and read-only filesystem check.
- **App behaviour:** runtime architecture comes from the Node binary, files resolve from the app directory, and the proxy tests confirm the asset-path fix. The issue verification records include before/after page and log comparisons, listen-error handling, and shutdown checks with idle and unfinished requests. These comparisons were reviewed, not repeated in full.
- **Test evidence:** the verification comments include negative controls against old or deliberately broken images, not only successful runs. The review independently reran the image and proxy suites and all six e2e scenarios on both cluster types.

## Follow-up before arm64 CI

**Make work item 3.3 depend on 4.1, or otherwise explicitly schedule 4.1 first.**

The [epic plan](plan.md#3-ci-and-publishing) lists only 2.5 and 2.6 as prerequisites for 3.3. However, [values.yaml](../../../deploy/helm/hello-kubernetes/values.yaml), lines 24-26, still pins pods to `kubernetes.io/arch: amd64`. On an arm64-only test cluster, the default installs cannot schedule, regardless of whether the arm64 image works.

This is already acknowledged in the [e2e work package's Open section](../2026-10-28-e2e-harness/plan.md#open) and the verification on #87. It is not a newly discovered image defect, but the main dependency table does not reflect it.

**Action:** add 4.1 to the prerequisites for 3.3 and to its issue dependencies when that issue is created. Do not remove the selector only through test overrides: the default chart must work on arm64.

**Proof:** after 4.1, run the image tests and e2e tests on native amd64 and arm64 runners. The arm64 page must report `linux/arm64`, and the default chart must schedule and become ready. I5a's simulated architecture mapping is useful, but does not prove that the real arm64 image builds or runs.

## Known release gates

- **E3 and E7 must become real passes in 4.1.** Both independently failed for the documented reasons: the quoted custom message produces invalid YAML, and restricted Pod Security rejects the pods. Remove their `EXPECTED_FAILURE` markers with the fixes. The current green harness result means four passes and two expected failures per cluster, not six passes.
- **CI and publishing remain workstream 3 work.** Load a single-platform image into each cluster, as #87 records, and make the required checks block publishing. Nothing in this review validates the future publishing workflow or a real arm64 build.

## Review checks

Run on 29 October 2026 in the devcontainer on amd64, using a fresh local image from the reviewed checkout.

| Command | Result |
|---|---|
| `docker build -q -t hk-workstream02-review:79083fc src/app` | Passed. |
| `test/image/run.sh hk-workstream02-review:79083fc` | I1-I7 and I5a passed. Trivy 0.76.1 found no fixable HIGH or CRITICAL vulnerabilities. |
| `test/proxy/run.sh hk-workstream02-review:79083fc` | P1-P3 passed. |
| `IMAGE=hk-workstream02-review:79083fc test/e2e/run.sh kind` | E1, E2, E4 and E11 passed; E3 and E7 were XFAIL for the documented reasons; no unexpected failures. |
| `IMAGE=hk-workstream02-review:79083fc test/e2e/run.sh k3d` | Same result as kind. |

Both clusters and their temporary kubeconfigs were removed by the harness. The temporary review image was removed afterwards. The shared checkout and unrelated changes were left untouched.

## Verification sources

The issue comments provide the checks that are not repeated above:

- [#75 image](https://github.com/paulbouwer/hello-kubernetes/issues/75#issuecomment-6461521915), [#77 dependencies and shutdown](https://github.com/paulbouwer/hello-kubernetes/issues/77#issuecomment-6462442308), and [#77 final dependency bump](https://github.com/paulbouwer/hello-kubernetes/issues/77#issuecomment-6484694185).
- [#81 asset paths](https://github.com/paulbouwer/hello-kubernetes/issues/81#issuecomment-6463384107), [#83 runtime architecture](https://github.com/paulbouwer/hello-kubernetes/issues/83#issuecomment-6463835398), and [#85 local startup](https://github.com/paulbouwer/hello-kubernetes/issues/85#issuecomment-6464151927).
- [#87 e2e verification](https://github.com/paulbouwer/hello-kubernetes/issues/87#issuecomment-6484477636) and the verification comment on [#90 image tests](https://github.com/paulbouwer/hello-kubernetes/issues/90).
