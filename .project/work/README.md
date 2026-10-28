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

One folder per piece of work, named `YYYY-MM-DD-slug`:

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
