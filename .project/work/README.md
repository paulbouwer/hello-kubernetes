---
title: Work
description: Plans for each piece of work we take on, with the intent, the rules to follow while building it, and the validation it must pass.
type: index
status: active
created: 2026-10-26
updated: 2026-10-26
---

# Work

The roadmap notes say *why* and *how* for each area. A work folder says what we are doing now: the intent, the decisions, the issues, the rules to follow while building it, and how to prove the result is good. People and agents read the work plan before they plan, build or test anything in it.

## Naming

One folder per piece of work, named `YYYY-MM-DD-slug`. Link each work package from the Plan column of its row in the epic's work plan, for example the [1.x work plan](2026-10-26-roadmap-1x/plan.md#work).

The name:

- `YYYY-MM-DD` is the date the folder was created. It never changes, so links stay stable.
- `slug` is 2 to 4 lowercase words joined with hyphens, e.g. `roadmap-1x`.

## Contents of a work folder

| File | Required | What it holds |
|---|---|---|
| `plan.md` | yes | Front matter with `type: plan`. Sections: **Intent**, **Decisions**, **Tracking**, **Work**, **Rules**, **Validation**, **Open**. |
| Other notes | no | Supporting material that is too long for the plan, e.g. a design sketch. Give each one the [front matter](../README.md#front-matter) and link it from `plan.md`. |

Verification results do not go here. They go in a comment on the issue, as set out in [AGENTS.md](../../AGENTS.md#verify-then-record).

## Status

`plan.md` is `active` while the work is in progress, and `done` when its issues are closed. If a later plan replaces it, set `status: superseded` and `superseded_by`. Never delete a work folder.

## Work

| Folder | Description | Status |
|---|---|---|
| [2026-10-26-roadmap-1x](2026-10-26-roadmap-1x/plan.md) | Deliver the 1.x roadmap in the 1.11 release, then deprecate the old image tags. | active |
| [2026-10-26-labels-and-board](2026-10-26-labels-and-board/plan.md) | Set up the 15 labels with a script that applies and checks them, the board statuses and workflows, and make the board public. | done |
| [2026-10-26-contributing-and-checks](2026-10-26-contributing-and-checks/plan.md) | Make CONTRIBUTING.md and AGENTS.md the source of truth for contributing, add the issue forms, PR template and release notes config, and enforce the conventions with workflows, repo settings and a ruleset. | done |
| [2026-10-27-community-triage](2026-10-27-community-triage/plan.md) | Rename invalid to not-aligned, close the PRs that don't fit the project with thanks, and label and reply to every other open community issue and PR. | done |
| [2026-10-27-dependabot-and-codeql](2026-10-27-dependabot-and-codeql/plan.md) | Add Dependabot version updates for the app, image, workflows and devcontainer, turn on CodeQL and secret scanning with push protection, and record how a CVE fix becomes a patch release. | done |
| [2026-10-28-node24-image](2026-10-28-node24-image/plan.md) | Move the image to node:24-alpine, pinned by digest, with a committed lockfile, a numeric non-root user and no package manager at runtime, and add image tests I1 to I3. | done |
| [2026-10-28-app-dependencies](2026-10-28-app-dependencies/plan.md) | Upgrade the app to Express 5, express-handlebars 9, pino 10 and pino-http 11 with a 7-day release cooldown, and stop the app cleanly on SIGTERM. | done |
| [2026-10-28-asset-paths](2026-10-28-asset-paths/plan.md) | Make the asset URLs relative when no render prefix is set, treat a prefix of only slashes as no prefix, and add proxy tests that prove it. | done |
| [2026-10-28-runtime-architecture](2026-10-28-runtime-architecture/plan.md) | Show the image architecture from the running Node binary, mapped to OCI names, and remove info.json. | done |
| [2026-10-28-run-locally](2026-10-28-run-locally/plan.md) | Make the app find its files from its own folder, and add make run, which installs the dependencies from the lockfile when they are out of date. | done |
| [2026-10-28-e2e-harness](2026-10-28-e2e-harness/plan.md) | Add an e2e harness that runs the chart on local kind and k3d clusters with the image built from the working tree, and the first scenarios E1 to E4, E7 and E11 on both. | done |
| [2026-10-29-image-tests](2026-10-29-image-tests/plan.md) | Add image tests I4 to I7: no fixable vulnerabilities, each platform starts and reports itself, PORT, and a read-only root filesystem. | done |
| [2026-10-29-vulnerability-scan](2026-10-29-vulnerability-scan/plan.md) | Rebuild the vulnerability scan with a pinned, checksum-verified Trivy that fails on fixable HIGH and CRITICAL findings, and place the review follow-ups in workstream 3. | done |
| [2026-10-29-ci-tests](2026-10-29-ci-tests/plan.md) | Run the image, proxy and e2e tests on every PR as required checks, on native amd64 and arm64, from one pinned tool table, and harden the test harness. | done |
| [2026-10-29-publish-images](2026-10-29-publish-images/plan.md) | Publish each release for amd64 and arm64 to Docker Hub and GHCR, with an SBOM and signed provenance, only from main and only after the tests pass. | done |
| [2026-10-29-pr-issue-resolver](2026-10-29-pr-issue-resolver/plan.md) | Find the PR's issue with one shared resolver in the issue check and the labels workflow, and fail a PR that points at more than one open issue. | done |
| [2026-10-29-devcontainer-tools](2026-10-29-devcontainer-tools/plan.md) | Make the devcontainer install Node.js, kubectl, Helm, Trivy, kind and k3d from the same pinned table as CI. | done |
| [2026-10-30-chart-secure-defaults](2026-10-30-chart-secure-defaults/plan.md) | Give the chart secure defaults that meet the restricted Pod Security Standard, fix its bugs, and run the e2e tests on arm64. | active |
