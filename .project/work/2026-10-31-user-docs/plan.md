---
title: User docs on the website
description: Move the user docs from the README and docs/ to the website, with E15 running the site's marked commands.
type: plan
status: in-progress
areas: [site]
issues: [141]
created: 2026-10-31
updated: 2026-10-31
---

# User docs on the website

## Intent

Move the user docs to the website, as the [website plan](../../roadmap/1.x/site.md#site-map) agreed. The README becomes a short front door, and `docs/` keeps the contributor docs. The commands on the site stay tested: E15 runs them, and C17 checks the values reference against the schema.

This is work item 5.3 in the [1.x work plan](../2026-10-26-roadmap-1x/plan.md#5-website). It is the largest item in workstream 5, so it lands in two PRs under #141.

## PRs

| PR | Pages | Other changes |
|---|---|---|
| A | Overview, Quick start; With Helm, With kubectl, With Kustomize, Behind an Ingress, Behind a Gateway; Values reference; Licences | The README rewrite, pointer pages for the old `docs/deploy-*.md`, E15 and C17 reading the site, the chart's and the release file's doc links, the sidebar icons, and no footer |
| B | Path prefixes, Security defaults; Show load balancing, Test your Ingress or Gateway; Container image, App settings, Upgrading from 1.10 | |

The Values reference moved into PR A, because C17 checks it, and the old Helm guide it came from became a pointer page.

## Decisions

| Decision | Result |
|---|---|
| Deploy pages | Each starts with a table of what it needs, where it installs and what you get, and ends with Verify, Upgrade, Uninstall and Requirements. |
| Code groups in E15 | A block in a code group is marked `e2e=<group>`. A page with groups runs once per group, with its plain `e2e` blocks. The quick start runs once for kubectl and once for Helm. |
| Sidebar icons | The Helm and Kubernetes pages use the black marks from CNCF artwork (commit `be95cf9`), drawn in the text colour, at the maintainer's suggestion. They are trademarks, used under the Linux Foundation guidelines only to name the tool. Other pages use Starlight's icons. |
| Footer | Removed, at the maintainer's request. The GitHub link in the header leads to issues and contributing. The font licences page became **Licences**, a sidebar item that covers the fonts, the icons and the copied Starlight code. |
| Quick start | `port-forward` connects to one pod, so the page no longer says the pod name changes on refresh. Showing that is the Show load balancing guide (PR B). |
| Links that go live at the release | The README, the chart's Artifact Hub link and the release file's header point to `paulbouwer.github.io/hello-kubernetes`, which deploys at 6.2. |

## Tracking

- **Issue:** [#141](https://github.com/paulbouwer/hello-kubernetes/issues/141), a sub-issue of epic [#54](https://github.com/paulbouwer/hello-kubernetes/issues/54).
- **Branches:** `docs/141-deploy-pages` (A), then a second branch for B, both from `release-1.11`.
- **Labels, milestone, assignee:** `documentation`, `area:site`, `v1.11`, @paulbouwer. PR A also touches the chart, the tests and a workflow.

## Validation

| Check | How |
|---|---|
| Build | `make site`: no type errors, and every internal link and anchor valid. |
| Browser | `make site-test`: every page, light and dark, with no console error, no request to another site, and no serious or critical axe problem. |
| Commands | E15 on k3d runs every marked block of the README and the site's pages, once per group, and the docs' clean-up leaves nothing. A typo in a grouped block fails it, naming the page and the group. |
| Values | C17 passes, and fails when a value is missing from the values reference. |
| CI | The required checks pass on each PR. |
