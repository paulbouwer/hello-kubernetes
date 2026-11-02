---
title: Workstream 04 review
description: Review of chart and deployment work, with one numeric image-tag defect to fix before release.
type: review
status: final
areas: [deploy, ci, operations]
created: 2026-10-30
updated: 2026-10-30
agent_harness: GitHub Copilot CLI
agent_harness_version: 1.0.103
agent_model: GPT-6.1 Sol
agent_model_id: gpt-6.1-sol
reviewed_commit: 86d602f43bd3cad2388486248be1f2c11636ea9a
---

# Workstream 04 review

## Scope and outcome

Review of workstream 4 in the [epic work plan](plan.md), covering #113, #115, #117, #119, #121, #123 and #127. This includes the chart, schema, release workflow, deployment guides, chart tests, e2e scenarios and local cluster tools. The work package plans, GitHub verification comments and later completion comments were included.

**One deployment-blocking defect needs fixing before 1.11.0: numeric image tags produce invalid image names.** The default chart and the tested routing paths look sound. The expanded native CI checks pass and are required. Minor issues are recorded below with their agreed placement.

No implementation changes were made as part of this review.

## Finding to address

**Placed in 4.8.**

### Numeric image tags pass validation but produce unusable images

**Location:** [image helper](../../../deploy/helm/hello-kubernetes/templates/_helpers.tpl), lines 29-31; [schema](../../../deploy/helm/hello-kubernetes/values.schema.json), lines 155-158; [C14 test](../../../test/chart/run.sh), lines 200-203.

The schema and Helm guide allow the image tag to be a string or a number. The helper formats the tag with `%s`, which does not accept a numeric value. Helm succeeds but puts a formatting error in the image name. A deployment with that name cannot start its containers.

From the repository root:

```bash
helm template demo deploy/helm/hello-kubernetes \
  --set deployment.container.image.tag=1
```

The rendered image is:

```text
paulbouwer/hello-kubernetes:%!s(int64=1)
```

A values file with the following supported input also fails:

```yaml
deployment:
  container:
    image:
      tag: 1.11
```

It renders `paulbouwer/hello-kubernetes:%!s(float64=1.11)`. A quoted tag works.

**Why the passing test misses it:** C14 uses `--set deployment.container.image.tag=1.11`. Helm parses that CLI value as a string, not a number. I confirmed its type through a client-side dry run. The test therefore does not exercise the numeric input it claims to cover.

**Required action:** convert the tag to text before formatting the image name. Keep the empty-tag fallback to `Chart.AppVersion` and the existing string behavior. Add regression cases for the integer CLI input and an actual numeric YAML value. Check the rendered image, not only whether Helm accepts the values. Both cases must produce valid image names without `%!s(...)`.

## What looks sound

- **The chart fixes address the earlier deployment gaps.** Defaults remove the amd64 selector, use non-root security settings and provide a writable `/tmp` with a read-only root filesystem. The chart quotes app values, normalizes prefixes and preserves the documented legacy ingress values. Ingress and HTTPRoute have separate tests for both rewrite modes.
- **The wider e2e checks are real release checks.** The reviewed commit passed kind and k3d on native amd64 and arm64, plus kind on Kubernetes 1.35. The ruleset requires all five e2e jobs, both image jobs, resolver tests, the scan and the issue check. The earlier expected-failure markers are gone. The recorded rolling-upgrade checks include failing controls before the preStop fix.
- **Publishing and its test mode remain separate.** The production checks align the git tag, app version, chart version and Artifact Hub image tag. The chart and rendered YAML are prepared for the release. Test mode uses GHCR and a test chart version; it does not prove the production release path. The successful chart test publish is recorded, including the fixes after earlier failed attempts.
- **The earlier script follow-ups are addressed.** Published-image verification uses the captured digest and separates Trivy findings from scan errors. Image startup diagnostics use a unique temporary file. The deployment guides and local cluster targets have recorded cluster checks, including the maintainer's later confirmation of forwarded-port access.

## Important release gates

These are planned checks, not new findings:

- **6.2 must prove the real published artifacts.** Check both image registries, version aliases, SBOM, provenance and signing. Run `SCAN=1 make verify-published` against the versioned images. Pull and verify the production OCI chart, compare the released YAML with the chart output, and check the Artifact Hub metadata and listing. The chart test publish does not replace these checks.
- **6.2 must check the published documentation paths and main-only automation.** The recorded guide tests use local substitutions because 1.11.0 is not published yet. Verify the actual chart, image and release URLs after publishing. Keep the daily published-image scan and labels-workflow checks from the earlier review.

The Helm 4-only decision is accepted. Chart and app release-version alignment still depends on the planned 6.2 version bump. The separate workflow-efficiency proposals remain deferred until after 1.11.

## Minor issues

- `test/e2e/run.sh:70-71`: reuses an existing kind cluster without checking its Kubernetes version, so local `make e2e-kind-oldest` can test 1.37 instead of 1.35. CI starts fresh clusters and is not affected. Placed in 4.9.
- `test/e2e/cluster.sh:96-111`: the k3d import check compares image names, not image IDs. An old same-tag image on a reused cluster can hide a failed import. Placed in 4.9.
- `Makefile:94-97`: `make e2e-clean` deletes the clusters directly and leaves `cloud-provider-kind` running, with its PID and log files. `make cluster-clean` handles these. Placed in 4.9.

## Review checks and limits

| Check | Result |
|---|---|
| `make test-chart` | Passed C1-C17. C14 has the numeric-input gap described above. |
| `helm lint --strict deploy/helm/hello-kubernetes` | Passed; only the recommended icon notice. |
| Extra integer and numeric YAML renders | Both reproduced the invalid image name. A quoted tag renders correctly. |
| `bash -n` on changed chart, image, e2e and installer scripts | Passed. |
| Workflow inspection | External actions in the changed test and publish workflows are SHA-pinned; both workflows have explicit permissions. |
| Live GitHub evidence | The reviewed commit's [Tests run](https://github.com/paulbouwer/hello-kubernetes/actions/runs/41027810194) and [scan](https://github.com/paulbouwer/hello-kubernetes/actions/runs/41027810381) passed. The [chart test publish](https://github.com/paulbouwer/hello-kubernetes/actions/runs/40995750581) passed on its earlier commit. |

The full image/e2e suites and devcontainer build were not repeated locally. Their recorded verification and GitHub results were reviewed. No cluster was started, release was published, registry was changed or workflow was dispatched.

## Verification sources

- [#113 chart defaults and arm64 verification](https://github.com/paulbouwer/hello-kubernetes/issues/113#issuecomment-6512914955).
- [#115 routing verification](https://github.com/paulbouwer/hello-kubernetes/issues/115#issuecomment-6513323940).
- [#117 schema verification](https://github.com/paulbouwer/hello-kubernetes/issues/117#issuecomment-6513542501).
- [#119 chart and YAML publishing verification](https://github.com/paulbouwer/hello-kubernetes/issues/119#issuecomment-6514257426) and [Artifact Hub follow-up](https://github.com/paulbouwer/hello-kubernetes/issues/119#issuecomment-6514429632).
- [#121 guide verification](https://github.com/paulbouwer/hello-kubernetes/issues/121#issuecomment-6515935952).
- [#123 routing and load-balancer checks](https://github.com/paulbouwer/hello-kubernetes/issues/123#issuecomment-6516485043), [rolling-upgrade checks](https://github.com/paulbouwer/hello-kubernetes/issues/123#issuecomment-6516970635), [oldest-version and guide checks](https://github.com/paulbouwer/hello-kubernetes/issues/123#issuecomment-6517626653), and [required-check enforcement](https://github.com/paulbouwer/hello-kubernetes/issues/123#issuecomment-6517723736).
- [#127 local cluster verification](https://github.com/paulbouwer/hello-kubernetes/issues/127#issuecomment-6518200206) and [maintainer's forwarded-port check](https://github.com/paulbouwer/hello-kubernetes/issues/127#issuecomment-6518649422).
