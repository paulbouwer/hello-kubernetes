---
title: Chart values schema
description: Add values.schema.json to the chart, so Helm checks values and editors and agents get descriptions and allowed values.
type: plan
status: done
areas: [deploy]
issues: [117]
created: 2026-10-30
updated: 2026-10-30
---

# Chart values schema

## Intent

Helm did not check the chart's values, so a typo such as `pathPrefx`, or a wrong type, was silently ignored or rendered wrongly. This work adds `values.schema.json`. Helm checks every install and upgrade against it, editors and agents get each value's description and allowed values, and it is the source for the values table (4.5) and the config builder (5.4), as [site.md](../../roadmap/1.x/site.md#agent-experience-ax) plans.

This is work item 4.3 in the [1.x work plan](../2026-10-26-roadmap-1x/plan.md#4-chart-and-deployment).

## Decisions

Made on 2026-10-30 (maintainer).

| Decision | Result |
|---|---|
| Unknown keys | Rejected in the parts the chart owns: the top level, `ingress`, `httpRoute`, `service`, `deployment`, `container` and `image`. `global` is allowed, for use as a subchart. Kubernetes objects (`annotations`, `tls`, `parentRefs`, `resources`, `nodeSelector`, `tolerations`, `affinity`, the security contexts) pass through, with only their type checked. |
| `message` | A string only. It is text to display, even when it is only a number. `--set message=42` fails with "got number, want string"; use quotes or `--set-string`. This also stops YAML turning `no`, `on` or `yes` into a boolean that the page would show as `false` or `true`. |
| Image tag | A string or a number, so `--set deployment.container.image.tag=1.11` keeps working. |
| Old names | `ingress.configured`, `ingress.pathPrefix` and `ingress.rewritePath` stay valid, with `"deprecated": true`. |
| Draft | JSON Schema draft-07, which Helm 4 and the YAML language server both support. |
| HTTPRoute | `parentRefs` is required when `httpRoute.enabled` is true. The template's own check stays, for `--skip-schema-validation`. |

## Tracking

- **Issue:** [#117](https://github.com/paulbouwer/hello-kubernetes/issues/117), a sub-issue of epic [#54](https://github.com/paulbouwer/hello-kubernetes/issues/54).
- **Branch:** `feat/117-chart-values-schema`, from `release-1.11`.
- **Labels, milestone, assignee:** `enhancement`, `area:deploy`, `v1.11`, @paulbouwer.

## Validation

| Check | How |
|---|---|
| Chart tests | `test/chart/run.sh`: C1–C16 pass. C12–C16 test the schema, and C6 tests both the schema and the template check. |
| The tests catch bugs | A value in `values.yaml` that the schema doesn't have, a missing description, `message` accepting numbers, and unknown top-level keys allowed each fail a scenario. Testing this found that a failed render stopped the test script under `set -e` with no FAIL line; renders now report as a failed scenario. |
| Lint | `helm lint --strict` passes. |
| Default chart | The e2e scenarios pass on kind and k3d. |
