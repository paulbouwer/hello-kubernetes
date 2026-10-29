---
title: Devcontainer tools
description: Make the devcontainer install Node.js, kubectl, Helm, Trivy, kind and k3d from the same pinned table as CI.
type: plan
status: done
areas: [operations]
issues: [99]
created: 2026-10-29
updated: 2026-10-29
---

# Devcontainer tools

## Intent

The devcontainer installed the latest release of each tool when it was built. Local versions could differ from CI, and could be newer than the 7-day cooldown in AGENTS.md rule 8 allows. This work makes the devcontainer use the same pinned, checksum-verified table as CI, so a test that passes locally passes in CI for the same reason.

This is a follow-up to 3.3 in the [1.x work plan](../2026-10-26-roadmap-1x/plan.md#3-ci-and-publishing).

## Decisions

Made on 2026-10-29.

| Decision | Result |
|---|---|
| Which tools | The tools that build, test and scan what is deployed: Node.js, kubectl, Helm, Trivy, kind and k3d, from `test/ci/install-tools.sh`. The developer tools that are never deployed (gh, Copilot CLI, Claude Code) keep tracking their latest release (maintainer). |
| Node.js | Added to the table at 24.22.1, the version in the app image. Released on 2026-10-20. Its tarballs for x64 and arm64 matched Node's published checksums. It unpacks into `/usr/local`, as before. |
| Build context | The repo root (`"context": ".."` in `devcontainer.json`), with a root `.dockerignore` that sends only `.devcontainer/github-latest-release.sh` and `test/ci/install-tools.sh`. The app image builds from `src/app`, with its own `.dockerignore`, so it is not affected (maintainer). |
| CI check | None for the devcontainer build (maintainer). |

## Tracking

- **Issue:** [#99](https://github.com/paulbouwer/hello-kubernetes/issues/99), a sub-issue of epic [#54](https://github.com/paulbouwer/hello-kubernetes/issues/54), blocked by #98.
- **Branch:** `build/99-devcontainer-tools`, from `release-1.11`.
- **Labels, milestone, assignee:** `enhancement`, `area:operations`, `v1.11`, @paulbouwer.

## Validation

| Check | How |
|---|---|
| Devcontainer build | `docker build -f .devcontainer/Dockerfile .` from the repo root on amd64: passes in 85 s, with a build context of 5.78 kB. |
| Versions | In the built image: Node.js 24.22.1, kubectl 1.37.1, Helm 4.3.1, Trivy 0.76.1, kind 0.33.0 and k3d 5.9.0, the same as the table. gh, Copilot CLI and Claude Code are installed. |
| Node.js in the table | `install-tools.sh node` into a scratch prefix installs `node` v24.22.1. |
| App image unaffected | `make build-image-linux` and `make e2e-image` build, and `make test-image` passes. |
| CI | The required checks pass on the PR. |
