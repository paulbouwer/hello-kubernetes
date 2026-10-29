---
title: Publish images
description: Publish each release for amd64 and arm64 to Docker Hub and GHCR, with an SBOM and signed provenance, only from main and only after the tests pass.
type: plan
status: active
areas: [ci, image]
issues: [102]
created: 2026-10-29
updated: 2026-10-29
---

# Publish images

## Intent

The publish workflow built for amd64 only, pushed to Docker Hub only, and published on any tag, tested or not. Its action was pinned by tag, it had no `permissions:` block (CodeQL alert #67), and the images had no SBOM or provenance. This work publishes each release as one multi-arch image to both registries, with records of what is in it and how it was built, and only from tested code on `main`.

This is work item 3.2 in the [1.x work plan](../2026-10-26-roadmap-1x/plan.md#3-ci-and-publishing). It takes the approach of PRs #40 and #46, which it credits and closes. The reasons are in row 4 of [review.md](../../roadmap/1.x/review.md#fixes-effort-and-impact).

## Decisions

Made on 2026-10-29.

| Decision | Result |
|---|---|
| Trigger | `push` of a `v*` tag publishes. A `publish-test-*` tag publishes only to GHCR as `test-<run number>`. Starting a workflow by hand needs it on `main`, so the test mode uses a tag. |
| Gate | The `check` job fails unless the tag is on `main` and matches `package.json` (a `v*` tag only). The full test suite (`tests.yaml`, now with `workflow_call`) must pass before `publish` runs. |
| Build | One job, with QEMU and Buildx, for `linux/amd64` and `linux/arm64`. The app is plain JavaScript, so emulation can't change the result, and 3.3 already tests both architectures natively (maintainer). |
| Tags | `X.Y.Z`, `X.Y` and `X` on `docker.io/paulbouwer/hello-kubernetes` and `ghcr.io/paulbouwer/hello-kubernetes`, from `docker/metadata-action`. No `latest` (maintainer). |
| SBOM and provenance | BuildKit adds an SBOM (SPDX) and SLSA provenance (`mode=max`) for each platform. `actions/attest-build-provenance` signs the provenance for each registry, so `gh attestation verify` can check it. No cosign (maintainer). |
| Actions | `docker/setup-qemu-action` v4.4.0, `setup-buildx-action` v4.4.1, `login-action` v4.6.0 (v4.7.0 was 6 days old), `metadata-action` v6.2.0, `build-push-action` v7.4.0 and `actions/attest-build-provenance` v4.2.2, pinned to commit SHAs. Least-privilege permissions: `packages: write`, `id-token: write` and `attestations: write` only on the publish job. |
| Published image scan | A `scan-published-image` job in the scan workflow scans `paulbouwer/hello-kubernetes:1` every day, and reports to code scanning under its own category. It runs from `main`, so it starts after 1.11 is released. |
| `make push-image` | Kept, for people who push to their own registry, which the build docs describe. It refuses to push to `docker.io/paulbouwer`: official images come only from CI (maintainer). |
| GHCR | The first push creates the package as private. The maintainer makes it public once, and deletes the test versions by hand. |
| PRs #40 and #46 | Closed with thanks when this work merges into `release-1.11` (maintainer). |

## Tracking

- **Issue:** [#102](https://github.com/paulbouwer/hello-kubernetes/issues/102), a sub-issue of epic [#54](https://github.com/paulbouwer/hello-kubernetes/issues/54), blocked by #75, #83 and #98.
- **Branch:** `ci/102-publish-images`, from `release-1.11`.
- **Labels, milestone, assignee:** `enhancement`, `area:ci`, `area:image`, `v1.11`, @paulbouwer.
- **Credit:** `Co-authored-by` trailers for @MrRoundRobin (#40) and @chazapis (#46).

## Validation

| Check | How |
|---|---|
| Test publish | A `publish-test-*` tag on this branch: `check` and the tests pass, and `publish` pushes `ghcr.io/paulbouwer/hello-kubernetes:test-<run>` only. |
| Both platforms | `docker buildx imagetools inspect` lists `linux/amd64` and `linux/arm64`. Pulling and running the arm64 variant shows `linux/arm64`. |
| SBOM and provenance | `imagetools inspect --format` shows an SBOM and a SLSA provenance for each platform. `gh attestation verify` passes for the digest. |
| No real tags touched | The Docker Hub tags are unchanged, and the workflow didn't log in to Docker Hub. |
| Release checks | A `v*` tag that doesn't match `package.json`, or isn't on `main`, fails `check`, and nothing is published. Checked by reading the script, and by running it locally with the same inputs, because pushing a real `v*` tag would be a release. |
| `make push-image` | Refuses `docker.io/paulbouwer`, and accepts another registry. |
| Pinning and permissions | Every `uses:` is a 40-character SHA, and the publish workflow has least-privilege permissions (CodeQL alert #67). |
