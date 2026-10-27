---
title: Community triage
description: Rename invalid to not-aligned, close the PRs that don't fit the project with thanks, and label and reply to every other open community issue and PR.
type: plan
status: active
areas: [operations]
issues: [71]
created: 2026-10-27
updated: 2026-10-27
---

# Community triage

## Intent

Most open community issues and PRs have had no reply for two to four years. Several people found real problems that 1.11 now fixes. This work tells each contributor what happens to their report or idea, thanks them, and labels each item, so that it can be tracked and is listed correctly in the release notes.

This is work item 1.3 in the [1.x work plan](../2026-10-26-roadmap-1x/plan.md#1-foundations). The decisions for each item are in [community.md](../../roadmap/1.x/community.md).

## Decisions

Made on 2026-10-27.

| Decision | Result |
|---|---|
| The `invalid` label | Renamed to `not-aligned`, with the description "Not aligned with the project's goals (see GOAL.md)". "Invalid" suggests that a contributor did something wrong, which is not true for most PRs that don't fit. The only reason to keep `invalid` was Hacktoberfest, which counts PRs only in repos with the `hacktoberfest` topic. This repo doesn't have it. |
| How to rename | `gh label edit` renames the label and keeps it on items. `labels.sh` gets the new name, and `invalid` goes on its remove list so that it can't come back. |
| PRs #41, #43, #48 | Closed with `not-aligned` and a comment. No type or area labels. |
| PRs #40, #45, #46 | Labelled, with a comment now. They stay open until the work that replaces them merges, so that the authors get a notification when their idea lands. |
| Open community issues | Labelled, with a comment, and added to the board in **Triage**, without the `agent` label. The 1.x sub-issues do the work, so the community issues are not picked up on their own. Each one is closed when the work that resolves it merges. |
| Voice | "We". No apology in each comment. One apology goes in the 1.11 release notes. |
| Approval | The maintainer approves the comment text in this plan before anything is posted, as rule 10 of the 1.x plan requires. |
| Issue creation | The board's Auto-add workflow adds new issues, so `gh issue create --project` now fails with "already exists". AGENTS.md says to let Auto-add do it. |

## Tracking

- **Issue:** [#71](https://github.com/paulbouwer/hello-kubernetes/issues/71), a sub-issue of epic [#54](https://github.com/paulbouwer/hello-kubernetes/issues/54), blocked by #56.
- **Branch:** `chore/71-community-triage`, from `release-1.11`.
- **Labels, milestone, assignee:** `enhancement`, `area:operations`, `v1.11`, @paulbouwer.

## Work

### 1. Rename the label (in the PR)

- `.github/labels.sh`: `not-aligned|e4e669|Not aligned with the project's goals (see GOAL.md)` in place of `invalid`, and add `invalid` to the remove list.
- `.github/release.yml`: exclude `not-aligned`.
- `AGENTS.md`: rule 5 ignores `not-aligned`, and the issue convention lets Auto-add put new issues on the board.
- operations.md and community.md: the label tables and the notes for #48, #41 and #43.

After the maintainer approves: `gh label edit invalid --name not-aligned --description "…"`, then `.github/labels.sh --check`.

### 2. Close #41, #43 and #48

Add `not-aligned`, comment, then close.

**PR #48** (@maddy00o7):

> Thanks for the PR. It adds a separate FastAPI service, which isn't part of what hello-kubernetes does, so we're closing it. If you meant to open it on your own fork, no problem.

**PR #41** (@szairi2011):

> Thank you for this. This PR sets the chart's default replica count for one deployment, so we won't merge it into the chart. You can get the same result without changing the chart:
>
> ```
> helm install hello-kubernetes ./deploy/helm/hello-kubernetes \
>   --set deployment.replicaCount=3
> ```
>
> The 1.11 docs will include a reference that lists every value you can set. We're closing this PR, but thanks for taking the time to send it.

**PR #43** (@szairi2011):

> Thank you for this. This PR sets the chart's default message and replica count for one deployment, so we won't merge it into the chart. You can get the same result without changing the chart:
>
> ```
> helm install hello-kubernetes ./deploy/helm/hello-kubernetes \
>   --set deployment.replicaCount=6 \
>   --set message="Hello there ... !!!"
> ```
>
> The 1.11 docs will include a reference that lists every value you can set. We're closing this PR, but thanks for taking the time to send it.

### 3. Label and comment on the items that stay open

Every comment ends with the same line:

> The project is active again, and this work is tracked in #54.

| Item | Labels | Board |
|---|---|---|
| #35 | `bug`, `area:image`, `area:deploy` | Triage |
| #38 | `bug`, `area:app` | Triage |
| #31 | `documentation`, `area:deploy` | Triage |
| #28 | `documentation`, `area:deploy` | Triage |
| #23 | `enhancement`, `area:deploy` | Triage |
| PR #40 | `enhancement`, `area:ci`, `area:image` | — (PRs aren't on the board) |
| PR #45 | `security`, `area:image` | — |
| PR #46 | `enhancement`, `area:ci`, `area:image` | — |

**#35** (@Alestrix):

> Thank you for reporting this. Your diagnosis is right: `USER node` is a name, so the kubelet can't check that the user isn't root. 1.11 fixes it in two places. The image runs as the numeric user `1000`, and the chart sets a `securityContext` with `runAsNonRoot: true` and `runAsUser: 1000`. We'll close this issue when both changes are merged, and you'll be credited in the release notes.

**#38** (@hotspoons):

> Thank you for the detailed diagnosis. You're right: with no `RENDER_PATH_PREFIX`, the page asks for `/css/main.css` from the domain root, which fails behind a path that isn't rewritten. 1.11 fixes how the template builds the asset paths. Thanks also to @ngaffa for the workaround in this thread. We'll close this issue when the fix is merged, and you'll be credited in the release notes.

**#31** (@kimllee):

> Thank you for reporting this. The example uses `networking.k8s.io/v1beta1`, which Kubernetes removed in 1.22. In 1.11 the chart creates the Ingress itself, or a Gateway API HTTPRoute, and the docs get worked examples for NGINX and Traefik. Thanks to @frayos for the working `v1` example, which we'll use as the starting point, and to @dcorbe for the input. We'll close this issue when the new docs are merged.

**#28** (@simonw):

> Thanks for asking. `helm uninstall` is in the Helm guide, but not in the quick start, where people look first. 1.11 adds a clean-up step to the quick start. Thanks to @dcorbe for answering here. We'll close this issue when the new docs are merged.

**#23** (@weironz):

> Thanks for asking. The `hello-kubernetes` chart on Artifact Hub today isn't from this repo. 1.11 publishes the chart as an OCI artifact to GHCR with each release, and adds an official Artifact Hub listing. We'll close this issue when that's in place.

**PR #40** (@MrRoundRobin):

> Thank you for this PR. It's the right idea, and 1.11 takes your approach: amd64 and arm64 images on Docker Hub and GHCR, built with `docker/metadata-action`, QEMU and Buildx, and a page that shows the architecture from the running process, as your change to `server.js` does. The actions in this PR are now several major versions old, so we'll rebuild the publish workflow instead of merging it, and credit you as a co-author on those commits. We'll keep this PR open and close it with a link when that work is merged.

**PR #46** (@chazapis):

> Thank you for this PR. 1.11 takes your ideas: multi-arch images and a numeric user `1000`, which also fixes #35. You'll be credited as a co-author on those commits. 1.x builds only `linux/amd64` and `linux/arm64`, because Node 24 has no official image for `arm/v7` and only an unofficial one for `riscv64`. A possible 2.0 rewrite could bring those platforms back. We'll keep this PR open and close it with a link when the new workflow is merged.

**PR #45** (@NikolaiThingnesLeira):

> Thank you for this PR. You were the first to send a fix for the out-of-date base image. Node 16 is also end-of-life now, so 1.11 moves to `node:24-alpine` instead. You'll be credited in the release notes. We'll keep this PR open and close it with a link when that change is merged.

### 4. Label only

- PR #30 and #44: `bug`, `area:deploy`. PR #30 is merged into `main` and not released yet, so its labels put it under Bug fixes in the 1.11 release notes.

### 5. Notes

- community.md: record that the items were labelled and answered, and the `not-aligned` label.
- operations.md: replace the "Labelling the current items" table with the result, and update the Filter section.
- Add this plan to `work/README.md`, and link it from the 1.3 row in the 1.x plan.

## Rules

The [1.x work plan rules](../2026-10-26-roadmap-1x/plan.md#rules) apply, and also:

1. **Post nothing before the maintainer approves the text.** Post the approved text exactly as it is.
2. **Label before you comment and close**, so that a notification shows the final state.
3. **Don't close any item except #41, #43 and #48.**

## Validation

Record the results in the verification comment on #71.

| Check | How |
|---|---|
| The label is renamed | `gh label list` shows `not-aligned` with the new description and no `invalid`. `.github/labels.sh --check` exits `0`. |
| Release notes leave it out | `generate-notes` on the branch doesn't list #41, #43 or #48, and lists PR #30 under Bug fixes. |
| Closed PRs | #41, #43 and #48 are closed, have `not-aligned`, and have the approved comment. |
| Open items | Each of #23, #28, #31, #35, #38, #40, #45 and #46 has the labels in the table and the approved comment, and is still open. |
| Board | #23, #28, #31, #35 and #38 are on the board in Triage. None has the `agent` label. |
| Labels only | PR #30 and #44 have `bug` and `area:deploy`. |
| Links | Every relative link and anchor in the changed notes resolves. |

## Open

- **When each fix merges**, close the community item it resolves with a link, and say which release it ships in. The 1.x sub-issues should list the community item they resolve, so this isn't missed.
- **In 6.2:** the release notes thanks with the one apology, and comments on the closed #16 (Raspberry Pi needs a 64-bit OS) and #29 (single-file YAML on each release).
