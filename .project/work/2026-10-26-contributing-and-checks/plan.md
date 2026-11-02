---
title: Contributing and checks
description: Make CONTRIBUTING.md and AGENTS.md the source of truth for contributing, add the issue forms, PR template and release notes config, and enforce the conventions with workflows, repo settings and a ruleset.
type: plan
status: done
areas: [operations]
issues: [59]
created: 2026-10-26
updated: 2026-10-27
---

# Contributing and checks

## Intent

Today the conventions for issues, branches, commits, PRs and verification are in [operations.md](../../roadmap/1.x/operations.md#conventions), which is a roadmap note, and nothing applies or checks them. This work moves them into `CONTRIBUTING.md` and `AGENTS.md`, which become the source of truth for contributing to the repo, for people and for agents. It then adds the files, workflows and settings that apply the conventions and stop a PR that breaks them.

This is work item 1.2 in the [1.x work plan](../2026-10-26-roadmap-1x/plan.md#1-foundations). It needs 1.1 ([#56](https://github.com/paulbouwer/hello-kubernetes/issues/56)), which set up the labels and the board.

## Decisions

Made on 2026-10-26.

| Decision | Result |
|---|---|
| Source of truth | `CONTRIBUTING.md` and `AGENTS.md`. The roadmap notes are temporary. operations.md keeps the reasons for the conventions and links to `CONTRIBUTING.md` for the rules. The work plans link to `CONTRIBUTING.md`. |
| What the two files cover | Contributing changes to the repo only. How to use the releases (Helm, kubectl, the image) is added in workstreams 4 and 5. |
| Split between the two files | Both are short. `CONTRIBUTING.md` is for people: how to contribute and how the process works, from issue to merge. It steers contributors to do the work with an agent that follows `AGENTS.md`. `AGENTS.md` gives agents the intent, the rules, the conventions in brief, and how to verify the work, and names the tools to use (for example the `gh` CLI) without step-by-step commands. |
| Claude Code | A `CLAUDE.md` with only `@AGENTS.md`, so that Claude Code loads the same rules. Copilot reads `AGENTS.md` itself. |
| Issue forms | `bug.yml` (label `bug`) and `feature.yml` (label `enhancement`). Plain titles: the maintainer changes the title to a conventional commit at triage. No `projects:` key, because the board's Auto-add workflow adds the issue. |
| Blank issues and questions | Blank issues are off. Discussions stay off for now, so `config.yml` links only to private vulnerability reporting. |
| Security | Turn on private vulnerability reporting, and add `SECURITY.md`, which says how to report and which versions get fixes. |
| Merge settings | Merge commits only. Squash and rebase merges are turned off. Branches are deleted after the merge. |
| Files read from the default branch | GitHub reads the issue forms, `config.yml`, the PR template and `SECURITY.md` only from `main`. They take effect when 1.11 merges into `main`, and are checked in 6.2. No exception to the release-branch flow (decided 2026-10-26). |
| Labels workflow runs from `main` | GitHub runs `pull_request_target` workflows only from the default branch, so `pr-labels.yaml` runs once 1.11 merges into `main`, and is checked in 6.2. Until then, labels and the milestone on PRs are set by hand (decided 2026-10-27). |
| Number of PRs | Two. PR 1 is the docs, templates and repo settings. PR 2 is the labeler, the issue check and the ruleset. PR 2 starts after PR 1 merges. |
| PR labels | The labeler applies the `area:` labels from the changed paths. A workflow copies the issue's type label (`bug`, `enhancement`, `documentation`, `security`, `dependencies`, `breaking-change`) and its milestone to the PR. |
| Finding a PR's issue | First from the head branch name (`{type}/{issue}-…`), then from an issue linked in the PR's Development section. The issue must be open and in this repo. |
| Fork PRs | Their branch names are not checked by anyone, so the check fails with a message that asks for an issue. The maintainer links the PR in the Development section and runs the check again. |
| Exempt PRs | Dependabot PRs, and PRs from a `release-*` branch into `main`. |
| Workflow triggers | The issue check runs on `pull_request` with read-only permissions, so it runs from the PR's own branch, and works for the first release PR into `main`, where the workflow is not on `main` yet. Labelling needs write access, so it runs in a separate `pull_request_target` workflow that never checks out the PR's code. |
| Ruleset | One ruleset for `main` and `release-*`: changes only through a PR (no approvals needed), merge commits only, signed commits, the issue check must pass, no force pushes, no branch deletion. Blocking deletion also stops "delete branch on merge" from deleting a release branch after the release PR into `main` merges. |
| Who can bypass the ruleset | The repository admin role (the owner), at any time, for emergencies. |
| When the settings change | The agent changes the merge settings and turns on vulnerability reporting while working on PR 1. The agent creates the ruleset after PR 2 merges, when the check runs on `release-1.11`. |

## Tracking

- **Issue:** [#59](https://github.com/paulbouwer/hello-kubernetes/issues/59), a sub-issue of epic [#54](https://github.com/paulbouwer/hello-kubernetes/issues/54), blocked by #56.
- **Branches:** `chore/59-contributing-and-checks` for PR 1. A second branch for PR 2, created after PR 1 merges, e.g. `chore/59-pr-checks`.
- **Labels, milestone, assignee:** `enhancement`, `area:operations`, `v1.11`, @paulbouwer.

## Work

### PR 1: docs, templates and settings

1. **`CONTRIBUTING.md`** at the root, short and for people:
   - How to contribute: open an issue first, and the maintainer triages it.
   - The process from issue to merge: the board statuses, release branches, and what happens after the merge.
   - Use an agent that follows `AGENTS.md` to do the work.
   - The essentials that people need to know: signed commits, merge commits only, and a PR must have an issue.
2. **`AGENTS.md`** at the root, short, with intent and steering rather than step-by-step commands:
   - What the repo is, its layout, and where the goal, roadmap and work plans are (`.project/`).
   - The rules for agents from [Workflow](../../roadmap/1.x/operations.md#workflow).
   - The conventions in brief: issues, branches, commits, PRs, labels and writing style.
   - How to verify the work and record the result.
   - The tools to use: the `gh` CLI for issues, PRs and the board, `helm`, `docker`, `kind` and `k3d`, and the devcontainer.
3. **`CLAUDE.md`** at the root, with `@AGENTS.md`.
4. **`SECURITY.md`** at the root: report through private vulnerability reporting, not a public issue. Fixes go into the latest 1.x release.
5. **`.github/ISSUE_TEMPLATE/`:**
   - `bug.yml`: what happened, what you expected, how to reproduce it, the image tag or chart version, how you installed it (Helm, kubectl or other), and the cluster. Label `bug`.
   - `feature.yml`: the problem, the change you propose, and other options you thought about. Label `enhancement`.
   - `config.yml`: `blank_issues_enabled: false`, and a contact link to `https://github.com/paulbouwer/hello-kubernetes/security/advisories/new`.
6. **`.github/pull_request_template.md`:** the Summary, Changes (with What, Why, Goal and Files for each group) and Verification sections, with short comments that explain each one.
7. **`.github/release.yml`:** categories in this order: Breaking changes (`breaking-change`), Security (`security`), Features (`enhancement`), Bug fixes (`bug`), Documentation (`documentation`), Dependencies (`dependencies`), then Other changes (`*`). Exclude `invalid`. GitHub puts a PR in the first category that matches, so a breaking or security change is listed only once, at the top.
8. **Repo settings**, with `gh api -X PATCH repos/paulbouwer/hello-kubernetes`:
   - `allow_squash_merge: false`, `allow_rebase_merge: false`, `allow_merge_commit: true`, `delete_branch_on_merge: true`.
   - Turn on private vulnerability reporting: `gh api -X PUT repos/paulbouwer/hello-kubernetes/private-vulnerability-reporting`.
9. **`.project` notes:**
   - operations.md: replace the Conventions section, the agent rules in Workflow and the Supporting files table with a short summary of the reasons and links to `CONTRIBUTING.md` and `AGENTS.md`. Add the epic and workstream tracking and the rule to keep the epic body up to date to `CONTRIBUTING.md` (the 1.x plan's Open item for 1.2), and remove that item.
   - Change the links to `operations.md#conventions`, `#issues` and `#verification` in the work plans and `work/README.md` to the file that now holds the rule.
   - Add this plan to `work/README.md`, and link it from the 1.2 row in the 1.x plan.

### PR 2: labels, issue check and ruleset

1. **`.github/labeler.yml`** with the path rules from the [area table](../../roadmap/1.x/operations.md#area), in the `actions/labeler` v5 format.
2. **`.github/workflows/pr-labels.yaml`**, on `pull_request_target` (`opened`, `edited`, `reopened`, `synchronize`):
   - `permissions:` `contents: read`, `pull-requests: write`, `issues: read`.
   - `actions/labeler`, pinned to a commit SHA.
   - A `gh` step that finds the PR's issue and copies its type label and milestone to the PR. It does nothing if there is no issue.
   - It never checks out the PR's code.
3. **`.github/workflows/pr-issue-check.yaml`**, on `pull_request` (`opened`, `edited`, `reopened`, `synchronize`) into `main` and `release-*`:
   - `permissions:` `contents: read`, `pull-requests: read`, `issues: read`.
   - One job, `issue-check`, using only `gh` and `jq`, which are on the runner.
   - It passes for Dependabot PRs, and for a `release-*` head into `main`.
   - Otherwise it reads the issue number from the head branch name, or else the issues linked in the Development section (GraphQL `closingIssuesReferences`). It passes if one of them is an open issue in this repo. Otherwise it fails, and its message says how to fix the problem.
4. **After PR 2 merges**, create the ruleset with `gh api repos/paulbouwer/hello-kubernetes/rulesets`:
   - Name `main and release branches`. Targets `refs/heads/main` and `refs/heads/release-*`.
   - Rules: `pull_request` (0 approvals, allowed merge method `merge`), `required_signatures`, `required_status_checks` (`issue-check`), `non_fast_forward`, `deletion`.
   - Bypass: the repository admin role, `always`.
   - Keep the JSON in the PR description or the verification comment, so the ruleset can be created again.
5. **operations.md and `CONTRIBUTING.md`:** say that the check, the labels and the ruleset now exist, and remove "Planned, not yet built".

## Rules

The [1.x work plan rules](../2026-10-26-roadmap-1x/plan.md#rules) apply, and also:

1. **One home for each rule.** A convention is written once, in `CONTRIBUTING.md` or `AGENTS.md`. The other file, operations.md and the work plans link to it.
2. **Keep `CONTRIBUTING.md` and `AGENTS.md` short.** No step-by-step commands. Agents work out the commands from the intent and the tools named.
3. **Pin every action to a full commit SHA**, with the version in a comment, and give every workflow a least-privilege `permissions:` block.
4. **Never check out or run the PR's code in a `pull_request_target` workflow.**
5. **No third-party actions** apart from `actions/labeler`. Use `gh` and `jq` for the rest.
6. **Test PRs are closed without merging**, and their branches are deleted.

## Validation

Record the results in the verification comment on #59. Run the PR 1 checks before PR 1, and the PR 2 checks before PR 2.

### PR 1

| Check | How |
|---|---|
| Conventions have one home | operations.md has no copy of the conventions or the agent rules, only the reasons and links. Each rule is in `CONTRIBUTING.md` or `AGENTS.md`, not both. Both files are short and have no step-by-step commands. |
| Agents load the rules | A new Claude Code session in the repo shows `AGENTS.md` loaded through `CLAUDE.md` (`/memory`). Copilot CLI lists `AGENTS.md` among its instructions. |
| Issue forms | **In 6.2, after 1.11 merges into `main`.** On the "New issue" page, only the bug and feature forms and the security link are shown, and there is no blank issue. A test issue from each form gets its type label and is added to the board in Triage. Delete both. |
| PR template | **In 6.2.** A new PR body starts with the template. Before then, the YAML of the forms and `config.yml` is parsed to check it is valid. |
| Release notes | `gh api repos/paulbouwer/hello-kubernetes/releases/generate-notes -f tag_name=v1.11.0-test -f target_commitish=<branch>` groups the merged PRs by type label (#52, #53, #55 and #58 should be in their categories). No release is created. |
| Merge settings | `gh api repos/paulbouwer/hello-kubernetes` shows only merge commits allowed, and `delete_branch_on_merge: true`. |
| Vulnerability reporting | `gh api repos/paulbouwer/hello-kubernetes/private-vulnerability-reporting` shows `enabled: true`. |
| Links | Every relative link and anchor in `.project`, `CONTRIBUTING.md` and `AGENTS.md` resolves. |

### PR 2

| Check | How |
|---|---|
| Area labels | **In 6.2.** A test PR that changes a file under `deploy/` gets `area:deploy`. Test PR #66 confirmed that the workflow does not run before then: no `pull_request_target` run exists. |
| Type label and milestone | **In 6.2.** A test PR from a `{type}/{issue}-…` branch gets the issue's type label and milestone. |
| Check passes with an issue | A test PR from a branch named for an open issue passes `issue-check`. |
| Check fails without an issue | A test PR from a branch with no issue number fails, with a message that says how to fix it. A branch named for a closed issue also fails. |
| Development link | Link the failing test PR to an open issue in the Development section, then run the check again. It passes. |
| Release PR | A test PR from a `release-*` branch into `main` passes without an issue. |
| Dependabot | Read the workflow: the Dependabot condition comes first. Checked for real in 1.4. |
| No PR code runs with write access | `pr-labels.yaml` has no `actions/checkout`, and runs no script from the PR. |
| Pinned and least privilege | Every `uses:` is a 40-character SHA, and each workflow has a `permissions:` block. |
| Ruleset | `gh api repos/paulbouwer/hello-kubernetes/rules/branches/release-1.11` and `…/main` list the five rules and the bypass. A test PR with an unsigned commit can't be merged without a bypass (`mergeStateStatus: BLOCKED`). A direct push to `release-1.11` is rejected, apart from the admin bypass. |

## Open

- **The labels workflow** is checked in 6.2, after 1.11 merges into `main`.
- **Re-running the check after a Development link.** Linking a PR does not trigger a workflow, so the check must be run again by hand. If this happens often, add a scheduled or `workflow_dispatch` re-check.
- **Signed commits from outside contributors.** Their unsigned commits block the merge. The owner can bypass, or ask the contributor to sign. Watch for this in 1.3, where the community PRs are closed or carried forward.
