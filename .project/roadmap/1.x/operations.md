---
title: Operations
description: Labels and what each drives, the project board, release branches, conventions for issues, branches, commits, PRs and verification, rules for agents, supporting files and label setup.
type: plan
status: active
areas: [operations]
created: 2026-10-23
updated: 2026-10-26
---

# Operations

How issues and PRs move through the repo: the labels, the project board, what each one drives, and the files that make the workflow run. The labels are designed so automation and autonomous agents can use them, not just people. This goes with [review.md](review.md) and the planning notes for each area.

## Approach

- **Every label is read by automation, or by an agent deciding what to do.** If a label doesn't drive something, it isn't added.
- **Workflow state lives on the project board, not in labels.** The board's Status field already tracks where an issue is, and its built-in workflows move items when PRs open and merge. Labels that repeat it (`status:ready`, `status:in-progress`) drift out of step with it, so they aren't used. The one exception is `needs-info`, because the stale bot can only read labels.
- **Type labels are unprefixed**, using the names GitHub tools already expect (`bug`, `enhancement`, `documentation`, `dependencies`), so release notes and Dependabot work without extra configuration.
- **Area labels are prefixed** with `area:`. It's the group automation filters on, and the prefix keeps the labeler rules readable. Kubernetes-style `kind/` and `priority/` groups would be overkill here.
- **Use built-in GitHub features where they exist:**
  - the project board for workflow state
  - close reasons for "duplicate" and "not planned"
  - issue dependencies ("blocked by") for blocked work
  - milestones (e.g. 1.11, 2.0) for release planning
  - Discussions for questions.

  Issue types would replace the type labels, but they're only available on organisation-owned repos, and this one is under a personal account.

## Current state (October 2026)

The repo has the 15 labels below, applied by `.github/labels.sh` on 26 October 2026 (#56). Issue forms, a PR template, `CONTRIBUTING.md` and `AGENTS.md` were added in #59. Discussions are off. The 1.11 work happens on the `release-1.11` branch and is tracked by the `v1.11` milestone.

## Labels (15)

### Type

One per issue or PR. Drives the sections of the release notes.

| Label | What automation does with it |
|---|---|
| `bug` | "Bug fixes" section. Agents reproduce the bug before fixing it. |
| `enhancement` | "Features" section. |
| `documentation` | "Documentation" section. Doc-only PRs skip the image build and scan. |
| `security` | "Security" section. No auto-merge; a human review is required. Use for fixes and scanner findings. Vulnerability reports go through private vulnerability reporting, not public issues. |
| `dependencies` | Applied by Dependabot. A separate release-notes section, and gates auto-merge of patch updates. |
| `breaking-change` | "Breaking changes" section, and a signal for a major version bump (e.g. going distroless in 2.x, per [image.md](image.md)). |

### Area

Auto-applied to PRs by file path (`actions/labeler`). Tells an agent which plan to read before starting.

| Label | Paths | Plan |
|---|---|---|
| `area:app` | `src/app/` (except the Dockerfile) | [image.md](image.md) (dependency upgrades) |
| `area:image` | `src/app/Dockerfile` | [image.md](image.md) |
| `area:deploy` | `deploy/`, `docs/deploy-*.md` | [deploy.md](deploy.md) |
| `area:ci` | `.github/workflows/`, `Makefile`, `test/` | [testing.md](testing.md), review item 3 |
| `area:site` | `site/`, `llms.txt` | [site.md](site.md) |
| `area:operations` | `.devcontainer/`, `docs/development-environment.md`, `.github/` other than workflows (`ISSUE_TEMPLATE/`, `labeler.yml`, `dependabot.yml`, `release.yml`), `AGENTS.md`, `.project/` | this note |

Notes:

- `area:deploy` covers the Helm chart, the rendered release YAML and the Kustomize guidance. Including `docs/deploy-*.md` means a deployment doc fix gets the area as well as `documentation`.
- `area:image` is only the published image. The devcontainer is the developer and agent workspace, and is unrelated to what ships, so it's under `area:operations`.
- `area:ci` is builds, tests and workflows. Repo configuration that happens to live in `.github/` (templates, labeler and Dependabot config) is `area:operations`.
- `area:operations` means maintaining the repo itself, not operating the app in a cluster. `AGENTS.md` is here rather than under `area:site` because it holds the repo-wide agent rules.

### Waiting on the reporter

| Label | What automation does with it |
|---|---|
| `needs-info` | Waiting on the reporter. The stale bot (`actions/stale`) closes only these, after about 30 days without a reply. Removing it, or a reply from the reporter, puts the issue back in triage. |

It's a label rather than a board status because `actions/stale` can only filter on labels.

### Agent trigger

| Label | What automation does with it |
|---|---|
| `agent` | Starts an agent run on an issue in **Ready** (e.g. the Claude Code GitHub Action's label trigger). Only people with triage permission can apply labels, so this is a safer go-ahead than a comment mention, which anyone can post. |

### Filter

| Label | What automation does with it |
|---|---|
| `invalid` | Not a contribution to this project (e.g. test or personal-fork PRs). Excluded from reports, triage and agent queues. Hacktoberfest also excludes PRs with this label (check the current year's rules). |

`invalid` replaces a `spam` label: it's less hostile, already exists, and has the same effect for Hacktoberfest. If Hacktoberfest doesn't matter, `off-topic` is more neutral, but no tooling recognises it.

### Remove

| Label | Instead |
|---|---|
| `duplicate` | Close as "duplicate" (built-in close reason) |
| `wontfix` | Close as "not planned" |
| `question` | Enable Discussions and link to them from the issue template chooser |
| `good first issue` | Not used |
| `help wanted` | Not used |

## Project board

The board is the user-owned project [hello-kubernetes (#5)](https://github.com/users/paulbouwer/projects/5), linked to the repo. Its Status field is the single source of workflow state. The board tracks **issues only**; PRs are reached through each issue's "Linked pull requests" field.

### Current state (26 October 2026)

Set up in #56.

- **Public.** Two views: "Milestone" (table) and "Board" (board).
- **Status options:** Triage, Ready, In Progress, In Review, Done, as in [Status options](#status-options).
- **Fields:** the built-in ones only (Assignees, Labels, Linked pull requests, Milestone, Parent issue, Sub-issues progress, and so on). No custom fields.
- **Built-in workflows:** set as in [Built-in workflows](#built-in-workflows). "Auto-add to project" adds new open issues in Triage. Issues that were open before it was enabled are added by hand (1.3).

### Status options

| Status | Change | Colour | Description | Meaning | How an issue gets there |
|---|---|---|---|---|---|
| Triage | Add | Gray | New, not yet looked at | New, not yet looked at | "Auto-add to project" (to enable), with "Item added to project" set to Triage |
| Ready | Rename from Todo | Green | Agreed and scoped. Agents may pick it up | Agreed and scoped, with clear acceptance criteria. The only issues agents may pick up | A person moves it after triage |
| In Progress | Keep | Yellow | Someone is working on it | Claimed, so two agents (or an agent and a person) don't take the same issue | The person or agent starting work. Agents can't always be assigned to issues, so moving the card is more consistent than assignees |
| In Review | Add | Blue | A PR is open for it | A PR is open for it | "Pull request linked to issue", set to In Review |
| Done | Keep | Purple | Merged into the release branch, and closed | The PR is merged into the release branch, and the issue is closed | Moved by the agent or a person after the PR merges ("Auto-close issue" then closes it), or "Item closed" if the issue is closed first |

Renaming Todo keeps its option ID, so the change is safe at any time. The description is what the board shows for the option. Gray, Green, Yellow, Blue and Purple run from not started to finished. Red and Orange are free for a blocked state if one is added later.

Done means merged, not released. Whether a change has shipped is tracked by the milestone (see [Release branches](#release-branches)).

### Built-in workflows

Workflows are configured in the project's settings (**⋯ → Workflows**). The API can list them but not change them.

| Workflow | Setting |
|---|---|
| Auto-add to project | **Enable**, repo `paulbouwer/hello-kubernetes`, filter `is:issue is:open`. Issue forms can add issues with `projects:`, but only when the person opening the issue can write to the project, so it doesn't work for outside reporters |
| Item added to project | Set Status to **Triage** |
| Pull request linked to issue | Set Status to **In Review** (the default is In Progress) |
| Item closed | Set Status to **Done** (default) |
| Auto-close issue | Keep. It closes an issue when it's moved to Done, which is the step that closes an issue after its PR merges into the release branch |
| Pull request merged | Leave on; it only acts on PR items, and PRs aren't added to the board |
| Auto-add sub-issues to project | Keep |

### Views

The views are "Milestone" (table) and "Board" (board). There is no view for the current release: project filters have no "current milestone" keyword (`@current` works only for iteration fields), so a release view would need its filter changed by hand for each release.

### Visibility

The project is public, so contributors and the people credited in [community.md](community.md) can see where their issues are. Changed from private on 26 October 2026 (#56).

### Notes

- **Agents need a token with project access** to read and move cards. The workflow's `GITHUB_TOKEN` can't reach a project owned by a personal account, so an agent workflow needs a personal access token with the `project` scope, stored as a secret. Check whether a GitHub App token can reach a user-owned project before relying on one.
- **Linking a PR to an issue has no API.** On a release branch, the PR link can only be set by hand in the Development section of the PR or the issue (see [Linking the PR to the issue](#linking-the-pr-to-the-issue)). `gh issue develop` links only the branch.
- **`gh` needs the `project` scope** to read or change the board: `gh auth refresh -h github.com -s project`, run in an interactive terminal.
- **The `agent` label and the board work together.** A maintainer applies `agent` only to an issue in Ready. The label is what triggers the run (label triggers are what the actions support); the board is what the agent checks and updates.

## Release branches

Release work happens on a release branch (currently `release-1.11`), which merges into `main` when the release ships.

- **PRs target the current release branch**, not `main`. The milestone (e.g. `v1.11`) on the issue says which release branch that is.
- **Create the branch from the issue**, so the branch is linked to it (see [AGENTS.md](../../../AGENTS.md#conventions)).
- **Link the PR to the issue by hand** in the Development section (see [Linking the PR to the issue](#linking-the-pr-to-the-issue)). Closing keywords don't work on a release branch, and the linked branch doesn't link the PR. Commit messages and PR bodies don't reference issues.
- **Close the issue when its PR merges into the release branch**, by moving it to Done. Add a short comment such as "Merged into `release-1.11` in #52. This ships in 1.11.0.", so a reporter knows it isn't released yet.
- **The milestone tracks the release.** It stays open while the release branch is in progress, and is closed when the release ships. Release notes are generated from the labels on merged PRs, not from issues.
- **Merge PRs with a merge commit**, not a squash or rebase. That keeps each signed commit unchanged, along with contributors' commits and `Co-authored-by` trailers. This applies to the final release-branch → `main` PR too.

## Conventions

The conventions for issues, branches, commits, PRs and verification are in [AGENTS.md](../../../AGENTS.md#conventions), and the process for people is in [CONTRIBUTING.md](../../../CONTRIBUTING.md). Those files are the source of truth. This section keeps only the reasons.

- **Conventional commit titles everywhere.** Issue, commit and PR titles share one format, so the type in a title sets the branch type and the type label, and tools can parse all of them.
- **Acceptance criteria are outcomes.** A person can check an outcome. A build step ("install kind") can be done without the result being right.
- **No issue references in commits.** The link between the work and the issue lives on the PR, where it can be changed. A commit message can't be changed after the merge.
- **Merge commits only.** A squash or rebase merge creates new commits, which drops the contributors' signatures and changes their commits. A merge commit keeps them.
- **Verification goes in an issue comment.** The issue is where the acceptance criteria are, and it stays after the branch is deleted.
- **Simple, direct language (ASD-STE100 style).** Many readers, people and agents, don't have English as a first language.
- **Every PR has an issue.** The work is driven from issues, and the issue holds the acceptance criteria and the board status.

### Linking the PR to the issue

GitHub keeps two separate links between an issue and the work for it:

| Link | Created by | Shows the PR in the issue's and PR's Development section | Fires the board's "Pull request linked to issue" |
|---|---|---|---|
| Linked branch | `gh issue develop`, or "Create a branch" on the issue | No | No |
| Linked PR | A closing keyword on a PR into the default branch, or a link made by hand in the Development section | Yes | Yes |

Release-branch PRs don't target the default branch, so the PR link has to be made by hand: on the PR, open **Development** in the sidebar and pick the issue. There's no API for it. This was confirmed on #51: its linked branch listed PR #53, but the issue had no linked PR until it was linked by hand.

## Workflow

```text
new issue ──> Triage ──> + needs-info ──> (no reply ~30 days) closed by stale bot
                │              │
                │        reply │ (label removed)
                ▼              ▼
              Ready <──────────┘
                │
                │  + agent (maintainer), or a person picks it up
                ▼
           In Progress ──> In Review ──────> Done
                          (PR into          (PR merged into release branch;
                         release branch)     issue closed, milestone stays open
                                             until the release ships)
```

The rules for agents are in [AGENTS.md](../../../AGENTS.md#rules). The stale bot is not set up yet.

## Supporting files

| File | Purpose | Status |
|---|---|---|
| `CONTRIBUTING.md` | The process for people, steering them to use an agent | Added in #59 |
| `AGENTS.md`, `CLAUDE.md` | The rules, conventions and verification for agents. `CLAUDE.md` imports `AGENTS.md` for Claude Code | Added in #59 |
| `SECURITY.md` | How to report a vulnerability privately | Added in #59 |
| `.github/ISSUE_TEMPLATE/bug.yml`, `feature.yml` | Issue forms that apply the type label (the board's Auto-add workflow puts them on the board) | Added in #59 |
| `.github/ISSUE_TEMPLATE/config.yml` | Turns off blank issues, and links to private vulnerability reporting | Added in #59 |
| `.github/pull_request_template.md` | The PR sections | Added in #59 |
| `.github/release.yml` | Groups generated release notes by the type labels | Added in #59 |
| `.github/labels.sh` | The labels, see [Setting up the labels](#setting-up-the-labels) | Added in #56 |
| `.github/labeler.yml`, `pr-labels.yaml` | The `area:` path rules above, and copying the issue's type label and milestone to the PR | Added in #59 |
| `pr-issue-check.yaml` and the ruleset | Require every PR to link an open issue, signed commits and merge commits on `main` and `release-*`. The ruleset is a repo setting, created after the workflow merged | Added in #59 |
| `.github/dependabot.yml` | `labels:` per ecosystem (e.g. `["dependencies", "area:image"]` for the app's Dockerfile, `["dependencies", "area:ci"]` for GitHub Actions, `["dependencies", "area:operations"]` for the devcontainer). Without it, Dependabot creates its own `javascript`, `docker` and `github_actions` labels | 1.4 |
| Stale workflow | `actions/stale` limited to `needs-info` | Not planned yet |
| Project board workflows | Set up in the project's settings rather than in the repo; see [Built-in workflows](#built-in-workflows) | Set up in #56 |

Discussions are off for now, so the issue chooser has no link to them.

## Labelling the current items

| # | Labels | Board |
|---|---|---|
| #50 update the devcontainer (PR #52, merged into `release-1.11`) | `enhancement`, `area:operations` (applied) | Done |
| #51 add the project notes | `documentation`, `area:operations` (applied) | In Progress |
| PR #30 probe paths with a path prefix (merged into `main`) | `bug`, `area:deploy` | Done |
| #44 probes fail with `pathPrefix` (closed by PR #30) | `bug`, `area:deploy` | Done |
| #35 `runAsNonRoot` fails | `bug`, `area:image`, `area:deploy` | Ready |
| #31 ingress example not working | `documentation`, `area:deploy` | Ready |
| #28 document how to delete | `documentation`, `area:deploy` | Ready |
| #38 handlebars refactor | `bug`, `area:app` | Triage |
| #23 Artifact Hub | `enhancement`, `area:deploy` | Triage |
| PR #48 (unrelated FastAPI service) | `invalid`, then close | — |
| PRs #41, #43 (personal values changes) | Close as "not planned" with thanks, as in [community.md](community.md); not `invalid` | — |

PR #30 needs its labels even though it's merged: the 1.11 release notes are generated from the labels on merged PRs. The other open PRs from [community.md](community.md) (#40, #45, #46) get type and area labels when they're closed.

## Setting up the labels

The labels are defined in [`.github/labels.sh`](../../../.github/labels.sh), which is the source of truth for their names, colours and descriptions. This note says what each label is for. The script needs `gh`, signed in with write access, and `jq`.

```bash
.github/labels.sh --check   # change nothing; list each difference and exit 1 if there is one
.github/labels.sh           # create, update and remove labels until the repo matches the list
```

Running the script again changes nothing. It deletes only the labels in its remove list (`duplicate`, `wontfix`, `question`, `good first issue`, `help wanted`). `--check` reports any other extra label, but the script never deletes it.

**Only the owner creates or changes labels.** To add or change a label, change the list in the script in a PR, update the tables above, and run the script after the merge. GitHub has no setting that limits label creation: anyone with write access can create labels, and on a personal repo every collaborator has write access. Today the owner is the only collaborator. After the 1.x work, a workflow will remove or report labels that are not in the script, and CODEOWNERS will make the owner the reviewer for it (see the [labels and board plan](../../work/2026-10-26-labels-and-board/plan.md#open)).
