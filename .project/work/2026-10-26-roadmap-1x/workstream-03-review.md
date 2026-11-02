---
title: Workstream 03 review
description: Review of CI and publishing, with working required checks and production publishing checks still due at release.
type: review
status: final
areas: [ci, image, operations]
created: 2026-10-29
updated: 2026-10-29
agent_harness: GitHub Copilot CLI
agent_harness_version: 1.0.103
agent_model: GPT-6.1 Sol
agent_model_id: gpt-6.1-sol
reviewed_commit: 6d0dfb39bd091fb65306991802eae332de2e6553
---

# Workstream 03 review

## Scope and outcome

Review of workstream 3, CI and publishing, in the [epic work plan](plan.md#3-ci-and-publishing), covering #94, #98, #102 and #95, plus the devcontainer follow-up #99. This includes the workflows, helper scripts, work package plans, issue verification comments and live GitHub checks. The correction to the scan diagnosis on #94 and the later verification comments on #98 and #102 were included. The review focused on major issues. Minor issues are recorded below with their agreed placement.

**No new major defect was found within this review's scope.** The required CI gates are active, native arm64 image testing is now proven, and the previous review's issue-resolution finding has been addressed. The remaining important checks are already tracked in 4.1 and 6.2. In particular, a successful GHCR test publish is not proof of the real Docker Hub release path.

No implementation changes were made as part of this review.

## What looks sound

- **The checks are enforced, not only reported.** The live ruleset for `main` and `release-*` requires `issue-check`, `workflow-tests`, both image-test jobs, both e2e jobs and the vulnerability scan. All five jobs in the [Tests run on the reviewed commit](https://github.com/paulbouwer/hello-kubernetes/actions/runs/40832838995) passed, as did its [scan](https://github.com/paulbouwer/hello-kubernetes/actions/runs/40832839043). The verification on #98 also demonstrates that a deliberately vulnerable PR was blocked.
- **Publishing runs its own tests on the tagged code.** The [publish workflow](../../../.github/workflows/build-and-publish-container-image.yaml) requires the version/main check and the reusable test suite before the publish job. Real release tags must match `package.json` and refer to a commit on `main`. Test mode uses only a GHCR test tag and skips Docker Hub. The [successful test publish](https://github.com/paulbouwer/hello-kubernetes/actions/runs/40827197296) confirms that the reusable tests ran before publishing.
- **The image records and scan have useful evidence.** The verification on #102 records both architectures, per-platform SBOM and provenance, and a verified signed attestation. The scan has a deliberate vulnerable-image failure test and reports all severities while gating fixable HIGH and CRITICAL findings. Actions are SHA-pinned, workflow permissions are explicit, and the shared [tool table](../../../test/ci/install-tools.sh) supplies pinned checksums.
- **The earlier review follow-ups are covered.** Both PR workflows now call the [same issue resolver](../../../.github/scripts/find-pr-issue.sh). Its tests cover closed, foreign, missing and ambiguous issues; the live check also exercised closed-issue fallback and ambiguity. The harness now matches the expected error before accepting XFAIL, reports failed cleanup, shows container startup errors, and prevents test containers from silently pulling another image. The devcontainer uses the shared tool installer.

## Important release gates

These are known follow-ups, not new implementation findings. Keep them as release requirements:

- **4.1: prove the default chart on arm64.** Native arm64 image and proxy tests pass, but arm64 e2e still waits for removal of the chart's amd64 selector. E3 and E7 must become real passes and lose their expected-failure markers.
- **6.2: exercise the real release path on both registries.** Verify `v1.11.0`, the version/minor/major tags, SBOM, provenance and signed attestations on Docker Hub and GHCR. Run `SCAN=1 make verify-published` against the versioned image in each registry. Docker Hub login, release tag generation and Docker Hub signing were skipped by test mode. The first-signing 404 and retry are already recorded on #102.
- **6.2: verify the jobs and automation that need `main`.** Confirm the new daily scan and published-image scan run, the old scanning alerts close, and the live labels workflow copies the linked open security issue's label and milestone. The resolver is tested, but the privileged labels workflow has not yet been proven live. Check the Trivy version against the cooldown policy before release.

## Minor issues

- `test/image/verify-published.sh:35,43,114`: after reading the digest, the script still checks the SBOM, provenance, config and scan through the tag. If the tag moves during the run, these checks can inspect a different image. Placed in 4.4, before 6.2 uses the script.
- `test/image/verify-published.sh:113-117`: a Trivy failure, such as a network, authentication or database error, is reported as vulnerabilities found, and its output is discarded. Placed in 4.4, before 6.2 uses the script.
- `test/image/run.sh:44,57,60`: the fixed `serve-page.err` filename can mix or lose startup errors from concurrent test runs on one machine. CI is not affected because each job has its own runner. Placed in 4.1.

## Review checks and limits

| Check | Result |
|---|---|
| `test/ci/find-pr-issue-test.sh` | Passed all 12 resolver cases and both workflow guards. |
| `bash -n` on the resolver, CI helpers and changed test scripts | Passed. |
| Read-only workflow checks | All external `uses:` entries are full commit SHAs; all five workflows have explicit permissions; publishing depends on the release check and reusable tests. |
| Live ruleset and GitHub runs | Required checks match the plan; the reviewed commit's test and scan runs passed. The GHCR test publish run passed. |
| `SCAN=1 test/image/verify-published.sh ghcr.io/paulbouwer/hello-kubernetes:test-42` | Cannot repeat: the test tag was deleted by hand after the #102 verification, as planned, so the script exited 2. The recorded passing check stands. This is not an open problem. No replacement tag was published. |

The full image/e2e suites and devcontainer build were not repeated locally: their GitHub results and recorded build evidence were reviewed. No real release, registry write or workflow dispatch was performed.

## Verification sources

- [#94 scan verification](https://github.com/paulbouwer/hello-kubernetes/issues/94#issuecomment-6487708718) and its [corrected diagnosis](https://github.com/paulbouwer/hello-kubernetes/issues/94#issuecomment-6488178073).
- [#98 CI and harness verification](https://github.com/paulbouwer/hello-kubernetes/issues/98#issuecomment-6488251944) and [required-check enforcement](https://github.com/paulbouwer/hello-kubernetes/issues/98#issuecomment-6488375759).
- [#102 publishing verification](https://github.com/paulbouwer/hello-kubernetes/issues/102#issuecomment-6489120911) and [published-image verification](https://github.com/paulbouwer/hello-kubernetes/issues/102#issuecomment-6489401427).
- [#95 resolver verification](https://github.com/paulbouwer/hello-kubernetes/issues/95#issuecomment-6489825594) and [#99 devcontainer verification](https://github.com/paulbouwer/hello-kubernetes/issues/99#issuecomment-6490141445).
