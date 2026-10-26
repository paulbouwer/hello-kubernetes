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

The repo has the 15 labels below, applied by `.github/labels.sh` on 26 October 2026 (#56). There are no issue templates or Discussions yet. The 1.11 work happens on the `release-1.11` branch and is tracked by the `v1.11` milestone.

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
- **Create the branch from the issue**, so the branch is linked to it (see [Branches](#branches)).
- **Link the PR to the issue by hand** in the Development section (see [Linking the PR to the issue](#linking-the-pr-to-the-issue)). Closing keywords don't work on a release branch, and the linked branch doesn't link the PR. Commit messages and PR bodies don't reference issues.
- **Close the issue when its PR merges into the release branch**, by moving it to Done. Add a short comment such as "Merged into `release-1.11` in #52. This ships in 1.11.0.", so a reporter knows it isn't released yet.
- **The milestone tracks the release.** It stays open while the release branch is in progress, and is closed when the release ships. Release notes are generated from the labels on merged PRs, not from issues.
- **Merge PRs with a merge commit**, not a squash or rebase. That keeps each signed commit unchanged, along with contributors' commits and `Co-authored-by` trailers. This applies to the final release-branch → `main` PR too.

## Conventions

These formats keep issues, branches, commits and PRs consistent, so people and agents can read and produce them the same way. They'll move into `CONTRIBUTING.md` (for people), `AGENTS.md` (for agents) and the templates in `.github/` (so they're applied automatically). This section keeps the reasoning.

### Writing style

Use simple, direct language, in the style of ASD-STE100 Simplified Technical English: short sentences, active voice, one idea per sentence, and common words. This applies to issues, PR descriptions and comments.

### Issues

- **Title:** a conventional commit, `type(scope): summary`, in lowercase and the imperative. The type also sets the branch type.
- **Body**, in three sections:
  - **Summary:** the problem, then what the issue does about it.
  - **Scope:** the files or areas it touches.
  - **Acceptance criteria:** a checklist.
- **Acceptance criteria describe outcomes**, which a person can check, not how to build them. Write "A developer can create and delete a local Kubernetes cluster in the container", not "Install kind in the Dockerfile".
- **Set everything when creating the issue:** the type label, the area label(s), the milestone and the board, e.g. `gh issue create --label enhancement --label area:operations --milestone v1.11 --project hello-kubernetes`.
- **Type label from the title's type:**

  | Conventional type | Type label |
  |---|---|
  | `feat`, `chore`, `build`, `ci`, `refactor`, `perf` | `enhancement` |
  | `fix` | `bug` (or `security` for a security fix) |
  | `docs` | `documentation` |

  Dependabot applies `dependencies` itself. Add `breaking-change` on top of the type label when it applies.

Example: [#50](https://github.com/paulbouwer/hello-kubernetes/issues/50).

### Branches

- **Name:** `{type}/{issue}-{slug}`, e.g. `chore/50-update-devcontainer`. The type matches the issue title's type. The slug is 2 to 4 lowercase words joined with hyphens. Leave the scope out, so there's only one `/`.
- **Base:** the PR's base branch, which is the release branch for the issue's milestone. When the base moves, rebase or merge it in.
- **Create it from the issue**, so the branch is linked to the issue:

  ```bash
  gh issue develop 51 --base release-1.11 --name docs/51-add-project-notes --checkout
  ```

  This links the **branch** only. The issue's Development section shows the branch, but a PR opened from it is not linked to the issue (see below).

#### Linking the PR to the issue

GitHub keeps two separate links between an issue and the work for it:

| Link | Created by | Shows the PR in the issue's and PR's Development section | Fires the board's "Pull request linked to issue" |
|---|---|---|---|
| Linked branch | `gh issue develop`, or "Create a branch" on the issue | No | No |
| Linked PR | A closing keyword on a PR into the default branch, or a link made by hand in the Development section | Yes | Yes |

Release-branch PRs don't target the default branch, so the PR link has to be made by hand: on the PR, open **Development** in the sidebar and pick the issue. There's no API for it. This was confirmed on #51: its linked branch listed PR #53, but the issue had no linked PR until it was linked by hand.

### Commits

- **Title:** a conventional commit. It can differ from the issue title.
- **Body:** a short paragraph that summarises the commit, then at most three bullet points of extra detail.
- **Agents add a `Co-Authored-By:` trailer** with their name, e.g. `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- **No issue references** (`Fixes #n`, `Refs #n`). The link lives on the PR.
- **Sign every commit.** The maintainer signs with an SSH key held in 1Password (`gpg.format ssh`, `gpg.ssh.program` set to `op-ssh-sign`), and GitHub shows the commits as Verified. Merge commits keep those signatures; squash and rebase merges recreate the commits.

```text
chore(devcontainer): update the development environment for developers and agents

Replace the Node.js 15 dev container with an Ubuntu 26.04 base that has
current tools for building, running and testing the app and the chart,
and the CLIs agents use. Tools track the latest release in each major
version and every download is verified against its published checksum.

- Add Node.js 24, kubectl, Helm 4, Trivy, kind, k3d, gh, Copilot CLI and Claude Code for amd64 and arm64
- Use docker-in-docker instead of the host Docker socket, and stop mounting the host ~/.kube
- Rewrite docs/development-environment.md, including how to use host clusters safely

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
```

### Pull requests

- **Title:** a conventional commit that describes this PR's change. One issue can have several PRs, so the title can differ from the issue's.
- **Body:**
  - **Summary:** one paragraph.
  - **Changes**, grouped by function or another meaningful category within the PR. Each group has a heading, then:
    - **What:** what changed
    - **Why:** why it changed
    - **Goal:** what the change is for
    - **Files:** a bullet list of the files.
  - **Verification:** a link to the verification comment on the issue.
- **Leave out** `Fixes #n` and any "generated by" footer.
- **Labels and milestone:** the same as the issue. PRs aren't added to the board.
- **Merge** with a merge commit, and delete the branch.

Example: [PR #52](https://github.com/paulbouwer/hello-kubernetes/pull/52).

### Verification

- **Check each acceptance criterion before opening the PR.** Tick only the criteria that were actually verified. Leave the others unticked, and say why.
- **Test failure paths too**, when a criterion is about something failing, e.g. a tampered download stopping the build.
- **Record the results in a comment on the issue:**
  - when, where and on which commit the checks ran
  - a table with the columns Criterion, Result (✅ or ⚠️) and Evidence
  - an **Open:** line for anything still to verify.

  Checks done by hand by the maintainer are recorded as such.

Example: [the verification comment on #50](https://github.com/paulbouwer/hello-kubernetes/issues/50#issuecomment-6392579940).

### After the merge

Comment on the issue that it's merged and which release it ships in, then move it to Done (see [Release branches](#release-branches)).

### Every PR has an issue

The work is driven from issues, so every PR must link one. Planned, not yet built:

- `.github/pull_request_template.md` with the PR sections above.
- **A check workflow** that fails a PR with no linked issue. Closing keywords don't link on release branches, and a PR linked by hand can only be checked after someone links it, so the check reads the issue number from the head branch name (`{type}/{issue}-…`), confirms that it's an open issue in this repo, and also accepts a PR linked through the Development section. Dependabot PRs are exempt.
- **A repository ruleset** on `main` and `release-*` that makes the check required.

### Epics

Each release has a parent issue, e.g. `chore(release): v1.11`, in the release milestone. Each work issue is a sub-issue of it. The board's "Auto-add sub-issues to project" workflow adds sub-issues to the board, and the Parent issue and Sub-issues progress fields show the progress. No `epic` label is needed. Not yet created for 1.11.

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

Rules for agents, to be written into `AGENTS.md`:

1. Only start work on issues in **Ready** on the board that are labelled `agent`.
2. Move the issue to **In Progress** when starting.
3. Read the plan for the issue's `area:` label first.
4. Create the branch with `gh issue develop` from the release branch for the issue's milestone, and open the PR against that release branch, not `main`. Linking the PR to the issue can't be done through the API, so ask the maintainer to link it in the PR's Development section.
5. Once the PR merges, comment on the issue that it's merged and which release it ships in, then move the issue to **Done**, which closes it.
6. Never merge anything labelled `security` or `breaking-change` without a human review.
7. Ignore anything labelled `invalid`.

## Supporting files

| File | Purpose |
|---|---|
| `.github/ISSUE_TEMPLATE/bug.yml`, `feature.yml` | Issue forms that apply the type label (the board's Auto-add workflow puts them on the board) |
| `.github/ISSUE_TEMPLATE/config.yml` | Turns off blank issues; links to Discussions and private security reporting |
| `.github/release.yml` | Groups generated release notes by the type labels |
| `.github/labeler.yml` | The `area:` path rules above, used by `actions/labeler` on PRs |
| `.github/dependabot.yml` | `labels:` per ecosystem (e.g. `["dependencies", "area:image"]` for the app's Dockerfile, `["dependencies", "area:ci"]` for GitHub Actions, `["dependencies", "area:operations"]` for the devcontainer). Without it, Dependabot creates its own `javascript`, `docker` and `github_actions` labels. |
| Stale workflow | `actions/stale` limited to `needs-info` |
| Project board workflows | Set up in the project's settings rather than in the repo; see [Built-in workflows](#built-in-workflows) |
| `.github/pull_request_template.md` | The PR sections from [Pull requests](#pull-requests) |
| PR issue check workflow and ruleset | Require every PR to link an issue (see [Every PR has an issue](#every-pr-has-an-issue)) |
| `CONTRIBUTING.md` | The [Conventions](#conventions) for people |
| `AGENTS.md` | The agent rules above, and the [Conventions](#conventions) for agents |

Pin every action to a commit SHA and give each workflow least-privilege `permissions:`, as in the rest of the repo's workflows.

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
