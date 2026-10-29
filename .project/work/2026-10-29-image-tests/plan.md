---
title: Image tests
description: "Add image tests I4 to I7: no fixable vulnerabilities, each platform starts and reports itself, PORT, and a read-only root filesystem."
type: plan
status: done
areas: [ci]
issues: [90]
created: 2026-10-29
updated: 2026-10-29
---

# Image tests

## Intent

`test/image/run.sh` checked the Node version, the CA bundle, the user and the architecture mapping (I1 to I3 and I5a). This work adds the rest of the image tests in [testing.md](../../roadmap/1.x/testing.md#image-tests), so that `make test-image` checks every guarantee the image makes. 3.3 runs the same tests in CI on amd64 and arm64.

This is work item 2.6 in the [1.x work plan](../2026-10-26-roadmap-1x/plan.md#2-image-and-app).

## Decisions

Made on 2026-10-29.

| Decision | Result |
|---|---|
| Order | #77 (the body-parser bump) merged first, so that I4 passes on a clean scan with no ignore file. |
| I4 | `trivy image --scanners vuln --severity HIGH,CRITICAL --ignore-unfixed --exit-code 1`. A failure lists each package, version, CVE and severity. If Trivy isn't installed, I4 fails, so it can't pass by not running. CI installs a checksum-verified Trivy (3.1, 3.3). |
| I5 | Runs the image with `--platform` for its own platform by default, and for each platform in `PLATFORMS` when it is set. The page must load and show the platform. arm64 is checked on native arm64 runners in 3.3, not here. |
| I6 and I7 | `-e PORT=9090` on port 9090. `--read-only --tmpfs /tmp`, which is what the chart's `readOnlyRootFilesystem` (4.1) needs: both the page and the stylesheet must load. |
| Layout | All in `test/image/run.sh`, in the order of testing.md, with one helper (`serve_page`) for I5 to I7. |

## Tracking

- **Issue:** [#90](https://github.com/paulbouwer/hello-kubernetes/issues/90), a sub-issue of epic [#54](https://github.com/paulbouwer/hello-kubernetes/issues/54), blocked by #75 and #83.
- **Branch:** `test/90-image-tests`, from `release-1.11`.
- **Labels, milestone, assignee:** `enhancement`, `area:ci`, `v1.11`, @paulbouwer.

## Validation

| Check | How |
|---|---|
| All pass | `make test-image` on the image built from `release-1.11`: I1 to I7 and I5a pass, in about 10 seconds. |
| I4 finds vulnerabilities | On the image from before #89: `FAIL I4: body-parser 2.3.0 CVE-2026-111181 HIGH`. |
| I4 without Trivy | With Trivy off the `PATH`: `FAIL I4: trivy is not installed`. |
| I5 | `PLATFORMS=linux/arm64` on the amd64-only image: `FAIL I5: linux/arm64: the page didn't load`. |
| I6 | An image whose command forces port 8080: `FAIL I6`. |
| I7 | An image that writes to its home directory at startup: `FAIL I7` with a read-only root filesystem. The same image serves the page when the filesystem is writable, so the failure comes from the read-only filesystem. |
