---
title: Node 24 image
description: Move the image to node:24-alpine, pinned by digest, with a committed lockfile, a numeric non-root user and no package manager at runtime, and add image tests I1 to I3.
type: plan
status: active
areas: [image]
issues: [75]
created: 2026-10-28
updated: 2026-10-28
---

# Node 24 image

## Intent

The image runs on Node 16 and Alpine 3.13, which are both end-of-life, as the named user `node`, which a cluster can't verify as non-root (#35). It has no lockfile, and npm starts the app. This work moves the image to a supported, patched base and a numeric user, with no behaviour change for people who use it.

This is work item 2.1 in the [1.x work plan](../2026-10-26-roadmap-1x/plan.md#2-image-and-app). The reasons are in [image.md](../../roadmap/1.x/image.md#step-1-node24-alpine). It resolves the image part of #35, and replaces PR #45.

## Decisions

Made on 2026-10-28.

| Decision | Result |
|---|---|
| Base image | `node:24-alpine`, pinned by digest to the multi-arch index (`sha256:06d7adf3…`), written out in both `FROM` lines so that Dependabot can update them. Node 24.22.1 on Alpine 3.24.3. |
| Build | Two stages. The first runs `npm ci --omit=dev` from the lockfile. The second copies `node_modules` and the app files: `package.json` and `info.json` are still read at runtime, until 2.4 removes `info.json`. |
| Lockfile | Generated from the current version ranges, in a `node:24-alpine` container. `package-lock.json` is removed from `.gitignore` and `src/app/.dockerignore`, which both ignored it. 2.2 upgrades the dependencies and regenerates it. |
| User | `USER 1000:1000`, the UID of the image's `node` user. |
| Start command | `CMD ["node", "server.js"]`. npm's start banner is no longer in the logs. |
| npm, corepack and Yarn | Removed from the runtime image. The app doesn't use them, and npm's bundled dependencies were the only fixable HIGH findings left. |
| Signal handling | Not changed here. `node` is PID 1 with no SIGTERM handler, as `npm` was, so a stop waits for the grace period. 2.2 adds a handler. |
| Architectures | Verified on amd64 here. The arm64 checks run in the CI matrix in 3.3. |
| Image tests | I1 to I3 in `test/image/run.sh`, with `make test-image`. I2 checks `ca-certificates-bundle`, because the `node` Alpine images don't install `ca-certificates`. 2.6 adds I4 to I7. |
| Version | `package.json` stays at 1.10.1. 6.2 sets the release version. |
| Review | Labelled `security`, so the maintainer reviews and approves the PR before the merge. |

## Tracking

- **Issue:** [#75](https://github.com/paulbouwer/hello-kubernetes/issues/75), a sub-issue of epic [#54](https://github.com/paulbouwer/hello-kubernetes/issues/54).
- **Branch:** `fix/75-node24-image`, from `release-1.11`.
- **Labels, milestone, assignee:** `security`, `area:image`, `v1.11`, @paulbouwer.
- **Credit:** `Co-authored-by` trailers for @Alestrix (#35), @chazapis (numeric user, #46) and @NikolaiThingnesLeira (#45).

## Work

1. Rewrite `src/app/Dockerfile`.
2. Commit `src/app/package-lock.json`, and stop ignoring it.
3. Add `test/image/run.sh` (I1 to I3) and `make test-image`.
4. Update image.md, testing.md (I2) and the 1.x plan (2.2 adds the SIGTERM handler; arm64 checks in 3.3).

## Validation

| Check | How |
|---|---|
| Image tests | `make build-image-linux`, then `make test-image`: I1, I2 and I3 pass. The same script fails I1, I2 and I3 on the old image. |
| No behaviour change | The old image (from `release-1.11`) and the new one, run with the default settings, `MESSAGE`, `PORT=9090`, `RENDER_PATH_PREFIX`, `HANDLER_PATH_PREFIX`, both prefixes, and `LOG_LEVEL=debug`. For each: the same page, byte for byte, and the same log fields and number of JSON log lines. |
| Vulnerabilities | Trivy finds no fixable HIGH or CRITICAL findings in the new image. |
| Lockfile | The image builds with `npm ci`, which fails if the lockfile doesn't match `package.json`. |

## Open

- **Close PR #45** with a link to the PR for this work after it merges, as promised in its comment.
- **#35 stays open** until 4.1 adds the chart's `securityContext`.
