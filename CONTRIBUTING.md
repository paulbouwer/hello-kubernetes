# Contributing

Thank you for helping with hello-kubernetes. This page explains how a change gets from an idea to a release.

## Start with an issue

Every change starts as an issue, and every PR must link one.

- **Bug or feature:** open an issue with the bug or feature form. Describe the problem, not only the fix.
- **Security problem:** don't open a public issue. Follow [SECURITY.md](SECURITY.md).
- **Small fix you want to make yourself:** open the issue first anyway, so it can be agreed before you spend time on it.

The maintainer triages each new issue. They set its labels and milestone, and give it a [conventional commit](https://www.conventionalcommits.org/) title. Then it moves to **Ready**.

## Do the work with an agent

We build with coding agents, such as GitHub Copilot or Claude Code. [AGENTS.md](AGENTS.md) has the rules, conventions and verification steps they follow. The fastest way to a PR that meets the conventions is to point your agent at the issue and let it follow AGENTS.md. Review what it does, as you would review a colleague's work.

The repo has a [devcontainer](docs/development-environment.md) with every tool the agents and the tests need.

If you work without an agent, read AGENTS.md anyway: the conventions are the same for people.

## How a change moves

| Board status | What happens |
|---|---|
| Triage | A new issue, not yet looked at. |
| Ready | Agreed and scoped. You or an agent can pick it up. |
| In Progress | Someone is working on it. |
| In Review | A PR is open for it. |
| Done | The PR is merged into the release branch, and the issue is closed. |

- **Work goes into a release branch**, for example `release-1.11`, not `main`. The issue's milestone tells you which one. The release branch merges into `main` when the release ships.
- **Name your branch for the issue:** `{type}/{issue}-{slug}`, for example `fix/35-numeric-user`. A PR belongs to exactly one issue: a check fails a PR that has no open issue, or that points at more than one.
- **Link the PR to the issue.** On a release branch, closing keywords don't work, so the maintainer links it in the PR's Development section.
- **Verify before you ask for review.** Check each acceptance criterion, and record the results in a comment on the issue.
- **Keep the docs runnable.** The e2e tests run every code block marked ```` ```bash e2e ```` in the README and the deployment guides. Mark a new block when it runs without input, and leave it unmarked when it doesn't.

## What every PR needs

- **Signed commits.** Set up [commit signing](https://docs.github.com/en/authentication/managing-commit-signature-verification) before your first PR. Unsigned commits can't be merged.
- **Merge commits only.** PRs are merged with a merge commit, so your commits and their signatures are kept as they are.
- **The PR template.** Fill in the summary, the changes and a link to the verification comment.

Labels are applied by the maintainer and by workflows. Only the maintainer creates or changes labels.

## Where the plans are

The goal, the roadmap and the plan for each piece of work are in [.project](.project/README.md). Read the work plan for an issue before you start on it.
