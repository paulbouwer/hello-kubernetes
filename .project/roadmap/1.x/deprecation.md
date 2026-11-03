---
title: Deprecating the old image tags
description: How every image tag before 1.11 gets a warning on its page that points to the fix, right after 1.11.0 ships, with the originals kept and the steps tested.
type: plan
status: published
areas: [image, operations]
issues: [154]
created: 2026-11-02
updated: 2026-11-03
---

# Deprecating the old image tags

## Intent

Every image before 1.11 runs an unsupported Node.js on an old base, with known vulnerabilities, and many are still pulled every day: AWS CDK's quick start uses 1.5, and tutorials, workshops and graders use the rest (see [review.md](review.md#published-images-and-their-source-commits)). Most of these people will never read a README or release notes. The page they deploy is the one channel that reaches all of them.

So, right after 1.11.0 ships, every old tag gets an image that shows a clear warning on its page and points to the fix. Nothing else changes, so nothing that works today breaks. The originals stay reachable under a second tag, and each tag can be rolled back.

This plan is work item 6.1 (#154). The maintainer signed it off on 2026-11-02, before anything was pushed. Publishing is 7.1, after 6.2 ships 1.11.0.

## Decisions

Made with the maintainer on 2026-11-02.

| Decision | Result |
|---|---|
| Which tags | All 13 old tags: `1.0`–`1.9`, `1.10.0`, `1.10.1` and `1.10`. `1.10` stays with 1.10.1, so it gets the warning too. |
| The floating tags | `1`, `1.11` and `1.11.0` point at 1.11.0, the fixed release. The publish workflow moves `1` and `1.11` when it publishes 1.11.0. Nothing moves `1.10`. |
| When | All at once, right after 1.11.0 ships, with no waves. The warning doesn't break anything, so there is nothing to stage. |
| How | A layer on each original, pinned by digest, not a rebuild from old commits. |
| The banner | A clear warning: an orange-red bar at the top of the page, saying the image is unsupported and has known vulnerabilities, and naming the upgrade. |
| The originals | Kept as Docker tags named `<tag>-original`, for example `1.5-original`, copied in the registry before each tag moves. No git tags. |
| Removal | The `-original` tags are removed 4 weeks after the warning images are published; that is the rollback window. The warning images stay. Whether to remove them is reviewed 6 months after, with Docker Hub's `last_pulled` dates and the state of the upstream fixes. The announcement says they "may be removed after" that date. |
| GHCR | From 1.11, the docs and the announcement recommend `ghcr.io/paulbouwer/hello-kubernetes`, which has no Docker Hub pull limits. Both registries keep getting every 1.x release, with the same SBOM, provenance and signed attestation. In 2.0, GHCR becomes the chart's default image, and Docker Hub's future is decided then. |

## The tags

The digests were read from Docker Hub on 2026-11-02, and match [review.md](review.md#published-images-and-their-source-commits). They are pinned in [`deprecation/tags.txt`](../../../deprecation/tags.txt).

| Tag | Original digest | Node | Runs as | Page made by | Becomes |
|---|---|---|---|---|---|
| `1.0` | `sha256:e2b6b91c…26a69f0` | 6.10.2 | root | `server.js` HTML | warning image |
| `1.1` | `sha256:d058499c…0d73` | 6.10.2 | root | `server.js` HTML | warning image |
| `1.2` | `sha256:a5365088…5357` | 6.10.2 | root | `server.js` HTML | warning image |
| `1.3` | `sha256:69d6e285…2676` | 8.1.0 | root | `server.js` HTML | warning image |
| `1.4` | `sha256:a9fc93ac…810b` | 8.1.0 | root | Handlebars layout | warning image |
| `1.5` | `sha256:88193b10…c04d` | 8.1.0 | root | Handlebars layout | warning image |
| `1.6` | `sha256:7326a73d…e258` | 13.6.0 | node | Handlebars layout | warning image |
| `1.7` | `sha256:b5b35951…4a30` | 13.6.0 | node | Handlebars layout | warning image |
| `1.8` | `sha256:6516f998…e3b4` | 13.6.0 | node | Handlebars layout | warning image |
| `1.9` | `sha256:be6b5ba3…62f0` | 13.6.0 | node | Handlebars layout | warning image |
| `1.10.0` | `sha256:08e951b9…f8b1` | 15.13.0 | node | Handlebars layout | warning image |
| `1.10.1` | `sha256:2ad94733…690b` | 16.10.0 | node | Handlebars layout | warning image |
| `1.10` | the same as `1.10.1` | 16.10.0 | node | Handlebars layout | warning image |
| `1`, `1.11`, `1.11.0` | — | 24 | 1000 | — | 1.11.0, in 6.2 |

All the old images are `linux/amd64` only, work in `/usr/src/app`, and start with `npm start`.

## The warning images

[`deprecation/deprecate.sh build`](../../../deprecation/deprecate.sh) writes a Dockerfile for each tag:

```dockerfile
FROM paulbouwer/hello-kubernetes@sha256:<original digest>
USER root                                   # only for the images that run as node
COPY patch.js banner.html notice.js.in /usr/src/app/.deprecation/
RUN DEPRECATED_TAG=<tag> node /usr/src/app/.deprecation/patch.js
USER node                                   # only for the images that run as node
LABEL org.opencontainers.image.description="DEPRECATED: …" \
      io.github.paulbouwer.hello-kubernetes.deprecated="true" \
      io.github.paulbouwer.hello-kubernetes.replacement="ghcr.io/paulbouwer/hello-kubernetes:1.11" \
      io.github.paulbouwer.hello-kubernetes.original="paulbouwer/hello-kubernetes@sha256:<original digest>"
```

`patch.js` runs once, at build time, with the image's own Node, and changes two things:

- **The page.** It puts [`banner.html`](../../../deprecation/banner.html) straight after `<body …>`: in `views/layouts/main.handlebars` for 1.4 to 1.10.1, or in the HTML string in `server.js` for 1.0 to 1.3. The banner has inline styles and no images, fonts or scripts, so it adds no requests. Its link to the upgrade page is followed only when clicked.
- **Startup.** It adds a `prestart` script to `package.json`, which npm runs before `npm start` starts the app. It prints the notice from [`notice.js.in`](../../../deprecation/notice.js.in) to stdout, so it shows in `kubectl logs`, and it never fails.

Everything else is the original's: the port, the path, the environment variables, the message and the page's content, the user, the command and entrypoint, the working directory, the static files and the exit behaviour. There are no delays and no deliberate failures.

The banner says, for example: **This image, hello-kubernetes 1.5, is deprecated.** It is unsupported and has known security vulnerabilities. Upgrade to `ghcr.io/paulbouwer/hello-kubernetes:1.11` or `paulbouwer/hello-kubernetes:1.11`. See [Upgrading from 1.10](https://paulbouwer.github.io/hello-kubernetes/docs/reference/upgrading/).

## Checks before publishing

`deprecation/deprecate.sh test` runs [`check.mjs`](../../../deprecation/check.mjs) on every built image. Each must pass all five before 7.1 publishes it.

| Check | Passes when |
|---|---|
| D1 | The image config is the original's: user, command, entrypoint, environment, ports, working directory, volumes and stop signal. The deprecation labels are set. |
| D2 | Run side by side with the same settings, the page is the original page with the banner added straight after `<body>`, and nothing else: with the banner removed, the two are the same, byte for byte. |
| D3 | The static files, the stylesheet and images, are byte for byte the original's. |
| D4 | The notice is in the container's logs, the original's own log lines are too, and the app answers within 3 seconds of when the original does. |
| K1 | On a kind cluster, each image passes HTTP liveness and readiness probes on `/` with no restarts, and its pod log has the notice. |

**Validated on 2026-11-02 (#154):** all 13 images built, and passed all five checks: 65 checks, in about 3.5 minutes. A patch that also changed the page outside the banner failed D2. Screenshots of 1.0, 1.3, 1.5 and 1.10.1 showed the banner above the unchanged page.

## The order, in 7.1

After 6.2 has published 1.11.0, and moved `1` and `1.11` to it:

1. **Build and test again**, from the same pinned digests: `deprecate.sh build`, then `deprecate.sh test`. Every check must pass.
2. **Publish:** `deprecate.sh publish --yes`. For each tag, it:
   1. refuses to run until `paulbouwer/hello-kubernetes:1.11.0` exists
   2. skips a tag whose current digest is no longer the original in `tags.txt`, so it never overwrites something it didn't expect
   3. copies the original to `<tag>-original`, in the registry, by digest
   4. pushes the warning image to `<tag>`, and prints the new digest
3. **Check the published tags:** each old tag's image has the deprecation label, each `-original` tag has the original digest, and `1`, `1.11` and `1.11.0` are 1.11.0.
4. **Announce it, the same day:**
   - **The Docker Hub overview:** a banner at the top, listing the deprecated tags, the replacement, and the table of original digests and `-original` tags.
   - **A pinned GitHub issue:** what changed and why, the dates, how to get the original back, and "use GHCR".
   - **The README:** a short note, linking the issue.
   - **The 1.11.0 release notes:** the same, with the upgrade note about `--reset-then-reuse-values`.
   - **The dates:** the `-original` tags are removed 4 weeks after publishing; the warning images may be removed after 6 months, when that is reviewed.
5. **Watch** the pinned issue and new issues for the 4 weeks.
6. **After 4 weeks,** remove the `-original` tags, unless a rollback is needed.

**Rollback:** point a tag back at its original, `docker buildx imagetools create -t paulbouwer/hello-kubernetes:<tag> paulbouwer/hello-kubernetes:<tag>-original`, and say why in the pinned issue.

## Caveats

- **Cached images:** nodes with an old image cached and `imagePullPolicy: IfNotPresent` show the warning only after they pull again, and anyone pinned to a digest never sees it. That's acceptable: the goal is to reach new deployments, such as people following old tutorials.
- **Still vulnerable:** the warning images still contain the old Node and OS packages. They point to the fix; they are not one. The banner says "has known security vulnerabilities, upgrade", never "patched".
- **Root:** 1.0 to 1.5 run as root, including 1.5, which AWS CDK uses. The pinned issue says so.
- **The Node.js advisory:** the review's notes on the October 2026 Node.js security release come from news coverage. Check Node's own release notes before quoting versions in the announcement.
- **Pull limits:** pushing 13 images and creating 13 tags uses the maintainer's Docker Hub account; run 7.1 when signed in.
- **Untested here:** `publish` was never run. It changes public tags, so the first run is 7.1's. Its guards, for 1.11.0 and for the original digests, are in the script for the maintainer to review.

## Published

On 3 November 2026 (#165), the maintainer ran `deprecate.sh publish --yes`, after the 13 digests were checked again and all 65 checks passed on images rebuilt that day.

| Date | What |
|---|---|
| 2026-11-03 | The 13 warning images published, and the 13 `-original` tags created. Announced in the pinned issue #167, the README, the 1.11.0 release notes and the Docker Hub overview. |
| 2026-12-01 | Remove the `-original` tags, unless a rollback is needed. |
| 2027-05-03 | Review whether to keep the warning images, with Docker Hub's `last_pulled` dates and the upstream fixes. |

**The `-original` tags are indexes.** `docker buildx imagetools create` doesn't retag a manifest: it writes a small image index that points to it. So each `<tag>-original` has a new digest of its own, and the original manifest, with its original digest, is inside it, unchanged. Pulling `<tag>-original`, or the original digest, gives the original image. Checked for all 13 tags on 2026-11-03, with `1.5` and `1.5-original` pulled fresh: the banner and the notice are on `1.5`, and not on `1.5-original`.

| Tag | Warning image | `-original` index |
|---|---|---|
| `1.0` | `sha256:06626f2e…44bf` | `sha256:86598edc…6a72` |
| `1.1` | `sha256:da2c8e11…f7b5` | `sha256:0f4ed968…2dd5` |
| `1.2` | `sha256:16f510a1…129e` | `sha256:313d8573…0fd9` |
| `1.3` | `sha256:92ace9af…d823` | `sha256:9a6be941…e5e5` |
| `1.4` | `sha256:201eef77…e171` | `sha256:ef4af5f6…710a` |
| `1.5` | `sha256:c1be33c4…1ae7` | `sha256:b5c6e1b4…eeac` |
| `1.6` | `sha256:5496c736…6d09` | `sha256:5fd71127…fa3b` |
| `1.7` | `sha256:0df725f7…ec98` | `sha256:7ef72aac…1282` |
| `1.8` | `sha256:56924afd…34cc` | `sha256:877df5ec…a534` |
| `1.9` | `sha256:9899f2b5…6f28` | `sha256:ce3b27e5…f33b` |
| `1.10.0` | `sha256:53d2a949…cc53` | `sha256:42dc3f11…d3a` |
| `1.10.1` | `sha256:c1636f78…a0c` | `sha256:179d04a5…743` |
| `1.10` | `sha256:93f97f9b…320` | `sha256:179d04a5…743` |

`1.10` and `1.10.1` have different warning images, because each banner names its own tag. `1`, `1.11` and `1.11.0` are still 1.11.0, `sha256:1334b75b…37ad`.

## Sign-off

- [x] The maintainer approves this plan, the banner and the notice, and the dates, for 7.1. Approved by @paulbouwer on 2026-11-02, after seeing the 1.10.1 warning image running on k3s (#154).
