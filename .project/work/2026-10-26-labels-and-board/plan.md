---
title: Labels and board
description: Set up the 15 labels with a script that applies and checks them, the board statuses and workflows, and make the board public.
type: plan
status: active
areas: [operations]
issues: [56]
created: 2026-10-26
updated: 2026-10-26
---

# Labels and board

## Intent

Make the repo's labels and the project board match [operations.md](../../roadmap/1.x/operations.md), so that automation and agents can rely on them. This is work item 1.1 in the [1.x work plan](../2026-10-26-roadmap-1x/plan.md#1-foundations), and 1.2, 1.3 and 1.4 wait for it.

The labels are kept in a script, so they can be applied again and checked for drift. The board changes are settings, and are recorded in operations.md.

## Decisions

Made on 2026-10-26.

| Decision | Result |
|---|---|
| Where the labels are defined | In `.github/labels.sh`. The script is the source of truth for names, colours and descriptions. operations.md says what each label is for. |
| What the script does | With no arguments, it creates, updates and deletes labels until the repo matches the list. With `--check`, it changes nothing, lists each difference, and exits non-zero when there is one. |
| Colours and descriptions | As in [Setting up the labels](../../roadmap/1.x/operations.md#setting-up-the-labels). The existing `bug`, `enhancement` and `invalid` labels are updated to match. |
| Who creates labels | Only the owner. GitHub has no setting that limits label creation: anyone with write access can create labels, and on a personal repo every collaborator has write access. Today the owner is the only collaborator, so the rule holds. operations.md records the rule. |
| Enforcing the label rule | After the 1.x work, not in 1.1 (decided 2026-10-26). A workflow removes or reports labels that are not in the script, and CODEOWNERS makes the owner the reviewer for the script. See [Open](#open). |
| Status options | The maintainer changes them in the web UI. The UI keeps Todo's option ID when it is renamed. The API replaces the whole list of options, which can give them new IDs and clear the status on existing items. |
| Built-in workflows | The maintainer sets them in the web UI. The API can list workflows, but not change them. |
| Board visibility | Public. |
| Board views | No change. Projects have no "current milestone" filter (`@current` works only for iteration fields), so no release view is added. |
| When the changes are made | During the work, before the PR, so that the verification comment shows real results. The agent applies the labels and the visibility. The maintainer does the UI steps, and the agent checks them through the API. |
| Front matter | Work plans can list their issues in a new optional `issues` field. |

## Tracking

- **Issue:** [#56](https://github.com/paulbouwer/hello-kubernetes/issues/56), a sub-issue of epic [#54](https://github.com/paulbouwer/hello-kubernetes/issues/54).
- **Branch:** `chore/56-labels-and-board`, from `release-1.11`.
- **Labels and milestone:** `enhancement`, `area:operations`, `v1.11`.

## Work

### 1. Label script

Add `.github/labels.sh`:

- Bash, with `set -euo pipefail`. It uses only `gh` and `jq`.
- The 15 labels as data at the top of the script: name, colour and description. The five labels to remove are a separate list.
- It reads the current labels once, with `gh label list --json name,color,description --limit 200`.
- Apply mode: `gh label create --force` for each label that is missing or different, and `gh label delete --yes` for each label in the remove list that exists. It prints one line for each change, and nothing for a label that already matches.
- `--check` mode: it prints `missing`, `different` or `extra` with the label name for each difference, and exits `1` if there is one. Colours are compared without case.
- An extra label is one that is in neither list. `--check` reports it. Apply mode never deletes it, because only the remove list is deleted.
- It works on the repo that `gh` resolves from the current directory, or on the one in `GH_REPO`.
- A short usage comment at the top.

### 2. Apply the labels

1. Run `.github/labels.sh --check`. Record the differences it finds.
2. Run `.github/labels.sh`.
3. Run `.github/labels.sh --check`. It must exit `0`.
4. Run `.github/labels.sh` again. It must print no changes.

### 3. Board changes by the maintainer

In the web UI for [project #5](https://github.com/users/paulbouwer/projects/5):

1. **Status field** (open the field settings from any view):
   - Rename **Todo** to **Ready**.
   - Add **Triage** and **In Review**.
   - Order: Triage, Ready, In Progress, In Review, Done.
   - Set the colour and description of each option from [Status options](../../roadmap/1.x/operations.md#status-options): Triage Gray, Ready Green, In Progress Yellow, In Review Blue, Done Purple. Ready keeps Todo's Green, and In Progress and Done keep their colours.
2. **Workflows** (**⋯ → Workflows**):
   - **Auto-add to project:** enable it for `paulbouwer/hello-kubernetes`, with the filter `is:issue is:open`.
   - **Item added to project:** set Status to **Triage**.
   - **Pull request linked to issue:** set Status to **In Review**.
   - Leave the other workflows as they are.

### 4. Board visibility

Run `gh project edit 5 --owner paulbouwer --visibility PUBLIC`.

### 5. Documentation

- **operations.md:**
  - Update the "Current state" sections for the labels and the board.
  - Change [Setting up the labels](../../roadmap/1.x/operations.md#setting-up-the-labels) to use the script, and keep the label list only in the script.
  - Say that only the owner creates labels, and how to add a label: change the script in a PR, then run it.
  - Remove the open question about visibility.
- **`.project/README.md`:** add the optional `issues` field to the front matter table.
- **`.project/work/README.md`:** add this plan to the table.
- **1.x work plan:** link this plan from the 1.1 row.

## Rules

The [1.x work plan rules](../2026-10-26-roadmap-1x/plan.md#rules) apply, and also:

1. **The script must be safe to run at any time.** Running it twice gives the same result. It never deletes a label that is not in the remove list.
2. **No third-party actions or tools.** Use `gh` and `jq`, which are in the devcontainer.
3. **Don't change the board through the API** apart from the visibility and reads. The status options and workflows are changed only in the UI.
4. **Leave existing items alone.** Don't add the open issues and PRs to the board, or label them. That is 1.3.

## Validation

Record the results in the [verification comment](../../roadmap/1.x/operations.md#verification) on #56.

| Check | How |
|---|---|
| The 15 labels are correct | `.github/labels.sh --check` exits `0`. `gh label list` shows 15 labels, and none of `duplicate`, `wontfix`, `question`, `good first issue` or `help wanted`. |
| Running the script again changes nothing | The second run of `.github/labels.sh` prints no changes. |
| The check finds drift | Create a stray label with `gh label create stray-test`, and change the colour of `needs-info`. `--check` exits `1` and names both. Then delete `stray-test` and run the script to restore `needs-info`, and `--check` exits `0` again. |
| The script has no syntax errors | `bash -n .github/labels.sh`. The devcontainer has no `shellcheck`, so run it in CI later if it is added. |
| Status options | A GraphQL query shows Triage, Ready, In Progress, In Review and Done, in that order, with the colours and descriptions from operations.md. #50 and #51 are still Done, and #54 and #56 are still In Progress. |
| Auto-add and Triage | Open a test issue. It is added to the board in Triage. Close it as "not planned" and delete it. |
| Item closed | The closed test issue moved to Done before it was deleted. |
| Pull request linked | When the maintainer links the PR for #56 in the Development section, #56 moves to In Review. |
| Board is public | `curl -s -o /dev/null -w '%{http_code}' https://github.com/users/paulbouwer/projects/5`, with no login, returns `200`. |
| Docs agree | operations.md has no description of the old labels or statuses as the current state. Every relative link and anchor in `.project` resolves. |

## Open

- **Enforce "only the owner creates labels".** Add a workflow that runs on the `label` event and removes or reports a label that is not in `.github/labels.sh`, and add `.github/CODEOWNERS` with the owner as the reviewer for the script. CODEOWNERS only takes effect once the ruleset from 1.2 requires a code owner review. Deferred until after the 1.x work, and listed in the [1.x work plan](../2026-10-26-roadmap-1x/plan.md#open).
- **Existing open issues are not on the board.** Auto-add acts only on issues that are opened or changed after it is enabled. 1.3 adds the open issues when it labels them.
