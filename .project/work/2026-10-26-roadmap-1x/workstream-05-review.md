---
title: Workstream 05 review
description: Review of the website, with one Helm command defect to fix before launch and explicit release checks.
type: review
status: final
areas: [site, ci, image, deploy]
created: 2026-11-02
updated: 2026-11-02
agent_harness: GitHub Copilot CLI
agent_harness_version: 1.0.103
agent_model: GPT-6.1 Sol
agent_model_id: gpt-6.1-sol
reviewed_commit: 6865a110601c15376047fb24ae1593b6d23b4abe
---

# Workstream 05 review

## Scope and outcome

Review of workstream 5 in the [epic work plan](plan.md#5-website), covering #137, #139, #141, #144, #146 and #148. This includes all six work packages, the [website decisions](../../roadmap/1.x/site.md), issue acceptance criteria, verification and completion comments, source, docs, tests and live GitHub checks. The later landing-page changes, including removal of the JSON-LD price, were included.

**One user-facing defect should be fixed in 6.2 before the site goes live: the builder's Helm commands break ordinary text messages.** All existing website checks pass, but their inputs miss this case. The preview, generated Markdown, bundled fonts and main-only deployment design look sound. Minor gaps and the five known follow-ups are recorded below.

Placements below are recommendations, not new agreed work items. No implementation or plan changes were made, and nothing was staged or committed.

## Finding to address

### Generated Helm commands do not preserve ordinary messages

**Suggested placement: 6.2, before Pages is enabled.**

**Location:** [builder.mjs](../../../site/src/lib/builder.mjs), lines 74-97; [drift cases](../../../site/tests/drift.mjs), lines 125-137.

The builder quotes text for the shell, but not for Helm's separate value parser. `--set-string` keeps scalar types as strings; it still interprets commas, backslashes and braces. Both the Helm install and template outputs use this code.

I ran the actual generated template commands, replacing only the published chart and version selection with the local chart:

| Message entered | Result |
|---|---|
| `Hello, Kubernetes!` | Helm fails: `key " Kubernetes!" has no value`. |
| `C:\demo` | Helm succeeds but sets `MESSAGE` to `C:demo`. |
| `{hello}` | Helm parses a list; the schema rejects it because `message` must be a string. |

For example, the builder emits `--set-string 'message=Hello, Kubernetes!'`. This fails even though the shell quotes are correct. Its `values.yaml` output preserves all three messages.

**Required action:** encode text for Helm's parser as well as the shell, or use a suitable literal-string mechanism. Keep valid messages valid. Add these inputs to the drift cases and compare the rendered `MESSAGE` with the original text. A successful Helm exit alone would miss the backslash corruption.

The existing S2 case uses quotes and HTML, but none of these characters. Passing that case is not proof that arbitrary message text survives.

## What looks sound

- **The checks are enforced.** The active ruleset requires `site` alongside the ten existing checks. On the reviewed commit, the [website run](https://github.com/paulbouwer/hello-kubernetes/actions/runs/41370262051), [native image/e2e run](https://github.com/paulbouwer/hello-kubernetes/actions/runs/41370262049) and [scan](https://github.com/paulbouwer/hello-kubernetes/actions/runs/41370262047) passed. The deployment job was skipped, as expected on `release-1.11`.
- **The docs and agent outputs have useful checks.** The site builds 20 pages, including the landing page and 404 page, and generates 18 docs copies. Internal links and anchors pass. The browser checks load every local link in `llms.txt`, check labelled code-group tabs, test the copy buttons and find no leftover component markup. C17 still checks the values reference against the chart.
- **The preview uses the app, not a second hand-written page.** All three S1 comparisons with a freshly built app image passed byte for byte. The other 24 drift checks cover the eight option sets and four landing chips. The preview's empty sandbox, escaped message and inlined assets passed the browser checks.
- **The recorded verification is generally careful about its limits.** The comments distinguish PR A from PR B, a local chart from a published chart, and a passing build from a real Pages deployment. They report the E09 rerun, the failed upgrade flag and the untested attestation command. The required-check follow-up on #139 was completed. The Helm-only hero and no-price JSON-LD are recorded maintainer decisions, not missing features.

### Acceptance and exit criteria

| Item | Assessment |
|---|---|
| 5.1, #137: bundled font | Met by the source, font hash checks and native image/proxy CI evidence. The font licence ships with the files. |
| 5.2, #139: scaffold and checks | Met, with the documented decision to drop CSP. `site` is required. Production deployment remains a 6.2 check. |
| 5.3, #141: migrated user docs | The pages, pointers, values reference and marked command flows are present and checked. The cleanup guard is narrower than its acceptance criterion; see Minor issues. |
| 5.4, #144: agent docs | Met for the built site. All 18 docs copies, the index, full text, schema and page actions passed. |
| 5.5, #146: builder and preview | Not fully met: the preview and tested option sets pass, but the command-output finding breaks valid messages. |
| 5.6, #148: landing page | Met against the recorded maintainer decisions. Chip behavior, lazy assets, metadata and accessibility checks pass. |
| Workstream exit criteria | The required checks pass, E15 runs the site's marked blocks in native CI, and the font no longer needs Google. The builder finding still needs a fix; green checks alone do not close it. |

### Security and supply chain

A separate bounded security review found no exploitable vulnerability:

| # | Severity | File | Lines | Vulnerability | Confidence |
|---|----------|------|-------|---------------|------------|
| - | - | - | - | None found in the bounded review | - |

The Pages actions are SHA-pinned. The build has read-only repository permissions and does not persist checkout credentials. Only the main-push deployment job receives Pages and OIDC write permissions. Playwright is digest-pinned. All 544 lockfile package entries have integrity values; the six vendored Ubuntu font hashes match their recorded values.

I also checked registry publication dates for all 538 distinct locked package versions, against the UTC day each version first entered the lockfile minus seven days. All passed. `npm audit signatures` verified all 468 installed packages; 157 also had verified attestations. This signature check does not cover optional packages that are not installed on this platform.

Dropping CSP was an accepted, documented choice. The tests observe requests; they are not a production network restriction. An iframe sandbox does not itself block network requests either. Current escaping and asset inlining provide the relevant guards. The browser tests passed with no request to another site.

## Important release gates

These are known follow-ups, not newly discovered implementation defects:

| Follow-up | Assessment and suggested placement |
|---|---|
| E09 flake on #142 | Still open. [E09](../../../test/e2e/scenarios/e09-pods-across-nodes.sh), lines 13-18, still sends only 20 requests immediately. Later green runs do not establish that the timing issue is fixed. **6.2:** use a bounded wait for more than one pod to answer, retaining failure on request errors and an eventual failure if routing never spreads. |
| Published-image attestation command | The guide matches the publisher's index-digest signing and the existing verifier, but it has not been run against the release image. **6.2:** run the exact Container image command against the first 1.11.0 image. Retain the chart-attestation and two-registry verification gates from workstream 4. |
| Upgrade from 1.10.1 | The failed `--reuse-values` attempt and successful `--reset-then-reuse-values` attempt are recorded, not concealed. The guides use the latter. **6.2:** put this warning in the release notes and verify the published-chart upgrade preserves custom values. |
| Preview asset size | The local build has a 357,827-byte preview-assets module and a separate 69,434-byte ConfigBuilder module. LandingDemo itself is 2,310 bytes, excluding shared chunks. The phone test confirms the preview assets wait until the mock-up approaches view. **After 1.11:** profile or reduce the assets if needed; this is not a launch blocker. |
| First Pages deployment | Still unverified, as recorded. **6.2:** the maintainer enables Pages after the release artifacts exist. Exercise the real main-branch deploy and check the base path, docs, Markdown copies, `llms.txt`, schema, images and 404 behavior on the public site. Update the README screenshot for the release. A PR artifact is not deployment proof. |

No new work is suggested for 6.1, which remains the old-tag deprecation plan. Keep the existing 6.2 gates and the deferral of workflow-efficiency proposals until after 1.11.

## Minor issues

- **6.2:** [E15](../../../test/e2e/scenarios/e15-docs.sh), lines 60-64, checks only Deployments, once after all pages and groups. It can miss a leftover Service, ServiceAccount, Middleware or namespace, or a later flow cleaning up an earlier flow's leak. Check cleanup per flow and include its other resources. This is a guard gap found by source inspection, not evidence that the current docs leak resources.
- **After 1.11:** [ConfigBuilder.tsx](../../../site/src/components/ConfigBuilder.tsx), lines 58-61, and [LandingDemo.tsx](../../../site/src/components/LandingDemo.tsx), lines 32-35, do not handle a rejected Clipboard API promise. A denied copy has no visible manual-copy fallback. The page-Markdown button already provides that pattern.
- **After 1.11:** [Overview](../../../site/src/content/docs/docs/start-here/overview.mdx), lines 20-21, has two empty table headers. axe reports `empty-table-header` in both themes. Add meaningful headers. This is minor and does not violate the agreed serious/critical accessibility threshold.

## Review checks and limits

| Check | Result |
|---|---|
| `npm run check && npm run build` in `site/` | Passed: no type errors, all internal links valid, 20 pages and 18 Markdown copies built. |
| `npx --no-install playwright test` in the Makefile's pinned Playwright image | Passed all 111 checks. Non-blocking accessibility warnings remain logged. |
| `IMAGE=hello-kubernetes:ws5-review-6865a11 node tests/drift.mjs` in `site/`, against a fresh local image | Passed all 27 checks. The review-owned image tag was removed afterwards. |
| Extra generated-command probes | Reproduced both parser failures and silent backslash corruption. The same messages survive the generated values file. |
| `make test-chart` | Passed C1-C17. |
| `npm audit signatures` in `site/` | Passed: 468 registry signatures and 157 attestations. |
| Registry publication-date audit | Passed all 538 distinct versions represented by 544 lockfile entries, including transitive and optional entries. The comparison uses their first lockfile commit dates. |
| Live ruleset and CI | `site` is required. All reviewed-commit test, scan and website jobs passed; Pages deployment was skipped. |

The full image/proxy/e2e suites were not repeated locally. Their native GitHub results and verification comments were reviewed. E15 substitutes the local chart, image, release file and Gateway; it does not prove published URLs or every unmarked/manual command. Markdown page actions work on a built site, not under `make site-dev`, as documented.

No cluster was started, release or image was published, workflow was dispatched, or Pages setting was changed. The shared checkout remains on `release-1.11`. `.agents/`, `.project/intelligence/` and the unrelated `.project/README.md` change were left untouched.

## Verification sources

- [#137 font verification](https://github.com/paulbouwer/hello-kubernetes/issues/137#issuecomment-6538023331).
- [#139 scaffold verification](https://github.com/paulbouwer/hello-kubernetes/issues/139#issuecomment-6538657699) and [required-check completion](https://github.com/paulbouwer/hello-kubernetes/issues/139#issuecomment-6538694632).
- [#141 PR A and E09 evidence](https://github.com/paulbouwer/hello-kubernetes/issues/141#issuecomment-6538955966), [PR B and upgrade evidence](https://github.com/paulbouwer/hello-kubernetes/issues/141#issuecomment-6540314742), and [release-note follow-up](https://github.com/paulbouwer/hello-kubernetes/issues/141#issuecomment-6551641019).
- [#144 agent-docs verification](https://github.com/paulbouwer/hello-kubernetes/issues/144#issuecomment-6551775046).
- [#146 builder and preview verification](https://github.com/paulbouwer/hello-kubernetes/issues/146#issuecomment-6552197146).
- [#148 landing verification](https://github.com/paulbouwer/hello-kubernetes/issues/148#issuecomment-6552888600) and [JSON-LD correction](https://github.com/paulbouwer/hello-kubernetes/issues/148#issuecomment-6566522074).
