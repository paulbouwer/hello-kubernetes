---
title: Workstream 01 review
description: Review of the Foundations work, with one issue-resolution gap to address before automatic PR labelling goes live.
type: review
status: final
areas: [operations, ci]
created: 2026-10-28
updated: 2026-10-28
agent_harness: GitHub Copilot CLI
agent_harness_version: 1.0.103
agent_model: GPT-6.1 Sol
agent_model_id: gpt-6.1-sol
reviewed_commit: d891714
---

# Workstream 01 review

## Scope and outcome

Review of workstream 1, Foundations, in the [epic work plan](plan.md#1-foundations), covering #56, #59, #71 and #73. The review considered the implementation on `release-1.11`, the work package plans, the issue verification comments and the live repository settings. Minor issues were excluded. No fixes were made as part of this review.

The work looks sound overall. The labels, board statuses, branch protections, merge settings and community triage outcomes match the plan. The verification records include meaningful failure-path checks, not only successful cases.

## Finding to address

**Align issue resolution in the PR check and the labels workflow before automatic labelling goes live.**

In [pr-labels.yaml](../../../.github/workflows/pr-labels.yaml), lines 34-47, the workflow resolves the issue differently from [pr-issue-check.yaml](../../../.github/workflows/pr-issue-check.yaml), lines 43-65:

- The issue check tries the branch number and linked issues, and accepts an open issue in this repository.
- The labels workflow takes the branch number when one exists, without checking that the issue is open. It does not fall back to a linked issue when that number is invalid or closed.
- When using linked issues, the labels workflow takes the first issue's number without checking its repository, then looks up that number in this repository.

A PR can therefore pass the required check for one issue but receive labels and a milestone from another. For example, a branch named for a closed issue can pass after the maintainer links an open issue, while the labels workflow still copies metadata from the closed issue.

This matters beyond cosmetic metadata: the `security` label requires human review under the agent rules. Copying from the wrong issue can omit that label.

**Recommended correction:** use the same issue-resolution rules in both workflows. Accept only open issues in this repository, fall back to linked issues when the branch candidate is not valid, and validate each linked issue's repository before using its number. Reuse the resolver if practical without running PR-controlled code in the write-enabled workflow.

**Verification for the follow-up:** cover a valid branch issue, a closed or invalid branch candidate with a valid linked issue, and a linked issue from another repository. Confirm that the check and label workflow select the same issue and copy its type labels and milestone, including `security` where applicable.

## Known release gates

These are already recorded in the plans, not unexpected blockers:

- Dependabot, automatic PR labelling, and the issue forms and PR template still need live verification after reaching `main`. Keep these checks explicit in work item 6.2.
- CodeQL does not currently run on PRs into `release-*`. Findings from release work surface on the release PR into `main`; review them before merging.

No other major issue was identified within this review's scope.
