---
title: Operations
description: Labels and what each drives, the project board, release branches, conventions for issues, branches, commits, PRs and verification, rules for agents, supporting files and label setup.
type: plan
status: active
areas: [operations]
created: 2026-10-23
updated: 2026-10-25
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

The repo has GitHub's eight default labels, plus `documentation` and `area:operations`, created for #50 and #51. There are no issue templates or Discussions yet. The 1.11 work happens on the `release-1.11` branch and is tracked by the `v1.11` milestone.

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

### Current state (25 October 2026)

- **Private.** Two unnamed views: "View 1" (table) and "View 2" (board). The first items are #50 (Done) and #51.
- **Status has GitHub's three defaults:** Todo, In Progress, Done.
- **Fields:** the built-in ones only (Assignees, Labels, Linked pull requests, Milestone, Parent issue, Sub-issues progress, and so on). No custom fields.
- **Built-in workflows enabled:** Item added to project, Item closed, Pull request linked to issue, Pull request merged, Auto-close issue, Auto-add sub-issues to project.
- **No "Auto-add to project" workflow**, so issues only reach the board if someone adds them.

### Status options

| Status | Change | Meaning | How an issue gets there |
|---|---|---|---|
| Triage | Add | New, not yet looked at | "Auto-add to project" (to enable), with "Item added to project" set to Triage |
| Ready | Rename from Todo | Agreed and scoped, with clear acceptance criteria. The only issues agents may pick up | A person moves it after triage |
| In Progress | Keep | Claimed, so two agents (or an agent and a person) don't take the same issue | The person or agent starting work. Agents can't always be assigned to issues, so moving the card is more consistent than assignees |
| In Review | Add | A PR is open for it | "Pull request linked to issue", set to In Review |
| Done | Keep | The PR is merged into the release branch, and the issue is closed | Moved by the agent or a person after the PR merges ("Auto-close issue" then closes it), or "Item closed" if the issue is closed first |

Renaming Todo keeps its option ID, so the change is safe at any time.

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

Name the two views (e.g. "Board" and "Triage table"), and add a 1.11 view filtered by `milestone:v1.11`.

### Visibility

The project is private, so contributors and the people credited in [community.md](community.md) can't see where their issues are. Making it public costs nothing for an open source repo. It's your call.

### Notes

- **Agents need a token with project access** to read and move cards. The workflow's `GITHUB_TOKEN` can't reach a project owned by a personal account, so an agent workflow needs a personal access token with the `project` scope, stored as a secret. Check whether a GitHub App token can reach a user-owned project before relying on one.
- **Linking PRs and issues has no API.** The Development link can only be set in the web UI, or created up front with `gh issue develop` (see [Branches](#branches)).
- **`gh` needs the `project` scope** to read or change the board: `gh auth refresh -h github.com -s project`, run in an interactive terminal.
- **The `agent` label and the board work together.** A maintainer applies `agent` only to an issue in Ready. The label is what triggers the run (label triggers are what the actions support); the board is what the agent checks and updates.

## Release branches

Release work happens on a release branch (currently `release-1.11`), which merges into `main` when the release ships.

- **PRs target the current release branch**, not `main`. The milestone (e.g. `v1.11`) on the issue says which release branch that is.
- **Create the branch from the issue**, so GitHub links them (see [Branches](#branches)).
- **Don't rely on closing keywords.** `Fixes #n` only links and closes an issue on a PR into the default branch, so it does nothing on a release branch. Link through the branch (above), or through the Development section of the PR or issue. Commit messages and PR bodies don't reference issues.
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
- **Create it from the issue**, so the branch and its PR are linked to the issue:

  ```bash
  gh issue develop 51 --base release-1.11 --name docs/51-add-project-notes --checkout
  ```

  There's no API for linking an existing PR to an issue. If a branch was created another way, link the PR by hand from the Development section of the PR or the issue.

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
- **A check workflow** that fails a PR with no linked issue. Closing keywords don't link on release branches, so it checks the head branch name (`{type}/{issue}-…`), confirms that the number is an open issue in this repo, and accepts a link made through the Development section. Dependabot PRs are exempt.
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
4. Create the branch with `gh issue develop` from the release branch for the issue's milestone, and open the PR against that release branch, not `main`.
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

`documentation` and `area:operations` were created on 25 October 2026 for #50 and #51. The rest isn't applied yet. With the GitHub CLI:

```bash
# Type
gh label create bug              --color d73a4a --description "Something isn't working" --force
gh label create enhancement      --color a2eeef --description "New feature or improvement" --force
gh label create documentation    --color 0075ca --description "Documentation only" --force
gh label create security         --color b60205 --description "Security fix or scanner finding; needs human review" --force
gh label create dependencies     --color 0366d6 --description "Dependency update" --force
gh label create breaking-change  --color e11d21 --description "Needs a major version bump" --force

# Area
gh label create area:app        --color c5def5 --description "Node app (src/app)" --force
gh label create area:image      --color c5def5 --description "Container image" --force
gh label create area:deploy     --color c5def5 --description "Helm chart, release YAML, Kustomize" --force
gh label create area:ci         --color c5def5 --description "Workflows, Makefile, tests" --force
gh label create area:site       --color c5def5 --description "Website, llms.txt" --force
gh label create area:operations --color c5def5 --description "Repo maintenance and dev environment" --force

# Waiting on the reporter
gh label create needs-info --color fbca04 --description "Waiting on the reporter" --force

# Agent trigger and filter
gh label create agent   --color 5319e7 --description "Approved for an agent to implement" --force
gh label create invalid --color e4e669 --description "Not a contribution to this project" --force

# Remove
gh label delete duplicate --yes
gh label delete wontfix --yes
gh label delete question --yes
gh label delete "good first issue" --yes
gh label delete "help wanted" --yes
```

`--force` updates an existing label (e.g. `bug`, `enhancement`, `invalid`) instead of failing.

