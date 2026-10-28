---
title: Dependabot and CodeQL
description: Add Dependabot version updates for the app, image, workflows and devcontainer, turn on CodeQL and secret scanning with push protection, and record how a CVE fix becomes a patch release.
type: plan
status: done
areas: [operations]
issues: [73]
created: 2026-10-27
updated: 2026-10-27
---

# Dependabot and CodeQL

## Intent

The image sat on an end-of-life base for years and nothing flagged it. This work adds the free GitHub tools that stop that happening again: Dependabot keeps the dependencies current, CodeQL checks our own code and workflows, and secret scanning stops leaked secrets. Trivy, rebuilt in 3.1, still checks what ships in the image, because none of these tools scan the OS packages or the Node runtime inside it.

This is work item 1.4 in the [1.x work plan](../2026-10-26-roadmap-1x/plan.md#1-foundations). The reasons are in [image.md](../../roadmap/1.x/image.md#what-github-provides).

## Decisions

Made on 2026-10-27.

| Decision | Result |
|---|---|
| When Dependabot starts | GitHub reads `dependabot.yml` only from `main`, so version updates start when 1.11 merges into `main`. They are checked in 6.2. By then 2.1, 2.2 and 3.x have done the major upgrades by hand, so Dependabot doesn't open PRs for the same work. |
| Target branch | `main`, the default. No `target-branch`. Security updates always target `main`. |
| Ecosystems | `npm` (`src/app`, `area:app`), `docker` (`src/app`, `area:image`), `github-actions` (`area:ci`), `docker` (`.devcontainer`, `area:operations`) and `devcontainers` (`area:operations`). Each PR has `dependencies` and the area label, set in the config. |
| Schedule and grouping | Weekly. Minor and patch updates are grouped into one PR per ecosystem. Major updates come as separate PRs. |
| Commit prefixes | `chore(deps)` for npm and the devcontainer, `build(deps)` for the image, `ci(deps)` for Actions. |
| Ignore | New major versions of the `node` base image. Node majors are planned work, tested on both architectures, and odd-numbered majors never get LTS. The docs don't say whether this also stops a security update. That's acceptable: a Node or Alpine CVE is fixed within the same major, and Trivy fails the build on anything this misses. |
| Auto-merge | No. |
| CodeQL | Default setup with the default query suite, for JavaScript/TypeScript and GitHub Actions. It is a repo setting, so it works now. It scans `main` on pushes and weekly, and PRs into `main`, but not PRs into `release-*`: PR #74 got no CodeQL run. So during release work, findings show on the release PR into `main`. A CodeQL workflow (advanced setup) could also scan `release-*` PRs, if that is needed later. |
| Secret scanning | On, with push protection. Push protection blocks any push that contains a detected secret, from anyone. Who may push to `main` and `release-*` is controlled by the ruleset from 1.2. |
| Trivy | Still needed. Dependabot fixes dependencies, CodeQL checks our code, and Trivy checks the finished image and fails the build. |

## Patch releases for CVE fixes

Dependabot security PRs target `main`. A fix becomes a patch release like this:

1. Merge the Dependabot PR into `main` with a merge commit. The issue check exempts Dependabot, and its commits are signed.
2. Create `release-1.11.1` from `main`, with a `v1.11.1` milestone and a release issue. Bump the versions there (`package.json`, the chart's `version` and `appVersion`), with any other fixes.
3. Open a PR from `release-1.11.1` into `main`. The issue check exempts release branches into `main`.
4. Tag `v1.11.1` on `main`. The publish workflow (3.2) builds and pushes the images and moves the `1.11` and `1` tags, and the release gets the rendered YAML (4.4).

6.2 writes this into `CONTRIBUTING.md` and `AGENTS.md` with the rest of the release process.

## Tracking

- **Issue:** [#73](https://github.com/paulbouwer/hello-kubernetes/issues/73), a sub-issue of epic [#54](https://github.com/paulbouwer/hello-kubernetes/issues/54), blocked by #56.
- **Branch:** `chore/73-dependabot-and-codeql`, from `release-1.11`.
- **Labels, milestone, assignee:** `enhancement`, `area:operations`, `v1.11`, @paulbouwer.

## Work

1. Add `.github/dependabot.yml` with the ecosystems, labels, prefixes, groups and ignore rule above.
2. Turn on secret scanning and push protection (`security_and_analysis` on the repo).
3. Turn on CodeQL default setup with the default query suite.
4. Update operations.md (supporting files) and image.md (what GitHub provides).
5. Add the 6.2 check for Dependabot to the 1.x plan.

## Validation

Record the results in the verification comment on #73.

| Check | How |
|---|---|
| Dependabot config is valid | The YAML parses. **In 6.2**, after 1.11 merges into `main`: the Dependabot page shows no config errors, and each ecosystem has run. |
| Dependabot PRs | **In 6.2.** A grouped PR for minor and patch updates has `dependencies` and its area label, a conventional commit title, and targets `main`. |
| CodeQL runs | The first default setup run succeeds and lists JavaScript/TypeScript and Actions. Code scanning shows CodeQL as a tool. |
| CodeQL on PRs | Check whether CodeQL runs on this PR into `release-1.11`. Record the result either way. |
| Secret scanning and push protection | The repo settings show both enabled. A push of a test secret to a throwaway branch is blocked. |
| Links | Every relative link and anchor in the changed notes resolves. |

## Open

- **Dependabot is checked in 6.2**, after 1.11 merges into `main`.
- **CodeQL found two alerts on `main`:** the old publish and scan workflows have no `permissions:` block. 3.1 and 3.2 rewrite both workflows, and the alerts close when that work reaches `main`.
- **The patch release process** goes into `CONTRIBUTING.md` and `AGENTS.md` in 6.2.
