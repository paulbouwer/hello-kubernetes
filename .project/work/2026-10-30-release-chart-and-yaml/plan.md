---
title: Release the chart and the rendered YAML
description: Publish the chart to GHCR and the rendered hello-kubernetes.yaml with each release, add Artifact Hub metadata, and fix verify-published.sh.
type: plan
status: done
areas: [ci, deploy]
issues: [119]
created: 2026-10-30
updated: 2026-10-30
---

# Release the chart and the rendered YAML

## Intent

A release published only the image. Helm users needed a clone of the repo, users without Helm had no manifest to apply (#29), and the only `hello-kubernetes` chart on Artifact Hub is unofficial (#23). This work publishes the chart as an OCI artifact on GHCR with each release, attaches the chart rendered with its defaults as `hello-kubernetes.yaml` to a draft GitHub release, and adds the metadata for an official Artifact Hub listing. It also fixes the two `verify-published.sh` issues from the [workstream 3 review](../2026-10-26-roadmap-1x/workstream-03-review.md#minor-issues).

This is work item 4.4 in the [1.x work plan](../2026-10-26-roadmap-1x/plan.md#4-chart-and-deployment), from [deploy.md](../../roadmap/1.x/deploy.md#rendered-yaml-on-each-release).

## Decisions

Made on 2026-10-30 (maintainer).

| Decision | Result |
|---|---|
| Static YAML | Keep one file, rendered from the defaults with the release name `demo`, so the resources are named `hello-kubernetes-demo`: no Ingress or route, and a `LoadBalancer` Service. It works with no changes on cloud clusters and on Docker Desktop, Rancher Desktop, OrbStack, k3s and k3d. On kind, minikube and bare metal the pods run and `kubectl port-forward` works. 4.5 documents this as a table. It is also the simplest Kustomize base. |
| Release | The workflow creates a **draft** release with generated notes and the file attached. The maintainer adds the credits and publishes it. |
| Versions | The chart, the app and the image share one version. The release check fails unless the tag, `package.json`, the chart `version`, `appVersion` and the `artifacthub.io/images` tag all match. |
| Chart registry | `oci://ghcr.io/paulbouwer/charts/hello-kubernetes`, with signed provenance. The maintainer makes the package public after its first push. |
| Artifact Hub | Keep it. It needs no stored credential: the maintainer adds the repository once on artifacthub.io, and Artifact Hub reads the public GHCR repo. The workflow pushes `deploy/helm/artifacthub-repo.yml` with the GHCR token, once `repositoryID` is set in it. #23 closes when the listing appears (6.2). |
| Test mode | A `publish-test-*` tag pushes the chart as `<version>-test.<run>` and keeps the file as a workflow artifact. No release, no Artifact Hub metadata. The maintainer deletes the test versions. |
| Tools | `oras` 1.3.5 (released 2026-10-19) joins the tool table, to push the Artifact Hub metadata. `actions/upload-artifact` v7.0.2 (2026-10-07) keeps the test file. |

## Tracking

- **Issue:** [#119](https://github.com/paulbouwer/hello-kubernetes/issues/119), a sub-issue of epic [#54](https://github.com/paulbouwer/hello-kubernetes/issues/54). Resolves #29 (closed, credited in the release notes) and #23 (closes in 6.2).
- **Branch:** `ci/119-release-chart-yaml`, from `release-1.11`.
- **Labels, milestone, assignee:** `enhancement`, `area:ci`, `area:deploy`, `v1.11`, @paulbouwer.

## Validation

| Check | How |
|---|---|
| Test publish | A `publish-test-*` tag on the branch: the chart is pushed as a test version with a verified attestation, the pulled chart renders the same as the file, and the file is a workflow artifact. No release is created. |
| Static YAML | The file from the test publish applies with `kubectl apply -f` to a k3d cluster with no Helm, and the page is served. |
| Release check | The version check passes with matching versions and fails with a mismatch, run locally. |
| `verify-published.sh` | It prints the digest it checks through. Against an image with findings, V6 reports vulnerabilities; with a broken Trivy database source, V6 reports a Trivy error. |
| CI | The required checks pass on the PR. |
