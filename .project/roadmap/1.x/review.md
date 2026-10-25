---
title: Maintenance review
description: What was found in October 2026, the seven fixes with effort and impact, who uses the old image tags, and deprecation images for them.
type: review
status: final
areas: [app, image, deploy, ci]
created: 2026-10-22
updated: 2026-10-25
---

# Maintenance review

I've reviewed the repo. The main problem is the base image, `node:16-alpine3.13`, and the eMudhra issue is only a small part of it. I couldn't run a fresh vulnerability scan because Docker isn't accessible from my sandbox, so the counts below come from your repo's own (outdated) scanner and are an undercount.

## What I found

**Base image (`src/app/Dockerfile:1`)**
- **Node 16** has been end-of-life since September 2023. It gets no security fixes, including the eMudhra one, which only went into Node 22.23.4, 24.22.1 and 26.12.1.
- **Alpine 3.13** has been end-of-life since November 2022. Your last scan logged "This OS version is no longer supported by the distribution".
- There are 10 open code-scanning alerts (8 error, 2 warning), in zlib, busybox and OpenSSL 1.1. They come from Trivy 0.19.2, which is about 5 years old and misses newer CVEs.

**eMudhra impact on this app is low.** Node uses its own built-in list of trusted certificate authorities, so an old Node keeps trusting the compromised eMudhra CAs. But that only matters when a program checks certificates as a TLS client. `server.js` is a plain HTTP server and makes no outbound TLS connections, so the app itself isn't exposed. What is exposed:
- anyone who uses your image as a base image, or runs `curl`/`wget` inside the container. Alpine 3.13's `ca-certificates` will never get the fix (`20261020-r0`).
- `npm install` at build time, which is a TLS client.

The bigger point is that the image can't be patched for this or anything else, because neither Node 16 nor Alpine 3.13 gets updates. That's a stronger reason to move than eMudhra.

**Dependencies:** `express-pino-logger` is deprecated (replaced by `pino-http`). `pino@6`, `express-handlebars@5` and `express@4.17` are all several major versions behind. There's no lockfile, and the Dockerfile runs `npm install` instead of `npm ci`, so builds aren't reproducible.

**Workflows:**
- The scan workflow is currently **disabled for inactivity**. It last ran 2026-08-11.
- The actions are old: `actions/checkout@v2`, `codeql-action/upload-sarif@v1`, and a Trivy binary fetched with `curl`, none pinned to a commit.
- `on: create` with a tag filter is fragile, and there's no `permissions:` block.
- There's no Dependabot, only amd64 is built, and images have no SBOM, provenance or signature.

**Helm chart and repo backlog:**
- No `securityContext`, and `USER node` isn't numeric, which breaks `runAsNonRoot` (#35).
- Probes fail when `pathPrefix` is set (#44, fix in PR #30).
- The ingress docs use `networking.k8s.io/v1beta1`, which has been removed from Kubernetes (#31).
- PR #48 is spam. PR #45 (base image update) and PRs #40/#46 (multi-arch) are stale.

## Fixes, effort and impact

| # | Fix | Effort for an agent | Impact |
|---|---|---|---|
| 1 | Base image → `node:24-alpine` (≥24.22.1, pinned by digest). Use multi-stage `npm ci --omit=dev`, numeric `USER 1000`, `CMD ["node","server.js"]` | **S** (~20 min) | **Critical.** Clears the old CVEs, picks up the eMudhra fix, fixes #35 |
| 2 | Upgrade deps: `pino-http` + `pino@9`, `express-handlebars@8` (small API change: `engine()`), `express@5` or latest 4.x. Commit a lockfile | **M** (~1 hr incl. smoke test) | High. Removes deprecated and outdated packages |
| 3 | Workflows: actions pinned to commit SHAs, `upload-sarif@v3`, the `trivy-action` (pinned), trigger on `push: tags: ['v*']`, least-privilege `permissions:`, re-enable the scan | **S–M** | High. A working scanner and less exposure to compromised actions |
| 4 | Publishing: `docker/build-push-action` building amd64 and arm64 (supersedes #40/#46), SBOM and provenance, cosign signing | **M** | Medium–High. arm64 is widely requested |
| 5 | Add `dependabot.yml` for npm, docker and github-actions | **S** (~5 min) | Medium. Keeps the image from going stale again |
| 6 | Helm: `securityContext` (non-root, read-only root filesystem, drop all capabilities), probe fix (#44/PR #30), `appVersion` bump, ingress docs to `networking.k8s.io/v1` (#31) | **S–M** | Medium. Users who copy the chart get secure defaults |
| 7 | Triage: close #48 and #45 (once #1 supersedes it), resolve the stale code-scanning alerts after rebuilding | **S** | Low, but tidies the repo before you announce anything |

In total that's about half a day of agent work plus your review. I can do it on a branch as one PR per row, or one combined PR, if you'd like.

## Who's affected

The image is used much more widely than the docs list suggested:
- **10.2 million pulls** on Docker Hub, and **every tag I checked (1.5, 1.8, 1.9, 1.10, 1.10.1) was pulled today**.
- **1,732 code hits on GitHub.** Notable ones:
  - `aws/aws-cdk-go`: the AWS CDK README, which generates all the docs.aws.amazon.com pages, is pinned to `1.5` from 2018.
  - `cdk8s-team/cdk8s-examples`
  - `GoogleCloudPlatform/professional-services`
  - `winglang`
  - `sipeed_wiki`
  - a large group of **42-school "Inception-of-Things"** student projects, which suggests it's in their curriculum.

## About archiving the old tags

**I'd recommend against deleting them, at least for now.** They're pulled daily, and deleting them would break the AWS CDK Quick Start, the DigitalOcean tutorial, workshops, student projects and other people's CI pipelines. That's a worse outcome for those users than an old image. A gentler path:

1. **Ship 1.11.0** (rows 1–3, behaviour unchanged) and move the floating `1` tag to it, so anyone on `:1` gets the fix automatically. Save breaking changes like the UID change and multi-arch for 2.0 if you prefer.
2. **Mark the old tags as deprecated where people will see it:**
   - a banner at the top of the Docker Hub overview listing unsupported tags and the replacement
   - a README banner
   - a pinned GitHub issue
   - release notes.

   Docker Hub has no per-tag deprecation flag I'm aware of, so the overview page is the main place to say it.
3. **Send fixes upstream yourself.** That reaches far more people than a notice:
   - a PR to `aws/aws-cdk`: bump `1.5` to `1.11` in the eks/eks-v2 READMEs, which updates the AWS docs pages
   - PRs to `cdk8s-team/cdk8s-examples` and `GoogleCloudPlatform/professional-services`
   - the DigitalOcean tutorial's feedback form
   - a short note to the 42 network.

   I can draft these PRs.
4. **Wait 6–12 months, then reconsider.** Use the Docker Hub `last_pulled` dates to decide whether removing something like `1.0`–`1.4` is safe. Those tags aren't referenced in any of the docs I found.

## Published images and their source commits

Read from the Docker Hub registry (image config labels `org.opencontainers.image.revision`, or the older `org.label-schema.vcs-ref` on 1.4) on 2026-10-22. Every listed commit exists in the repository.

| Tag | Image digest | Commit | Node | Runs as | Last pulled |
|---|---|---|---|---|---|
| 1.0 | `sha256:e2b6b91c8cad617222c76063e24569eb3d2b3234ca07488db243ab68126a69f0` | **none**: no labels, built Apr 2017, before the repo's first commit | 6.10.2 | root | 2026-10-19 |
| 1.1 | `sha256:d058499caca5c26c9e99e586089c39b676178e0a0740434ee42ca91627d14d73` | **none** (Apr 2017) | — | root | 2026-10-19 |
| 1.2 | `sha256:a53650885c21b4f6f284380db6e67ccbeb2159a23d4515913dba31384a665357` | **none** (Apr 2017) | — | root | 2026-10-19 |
| 1.3 | `sha256:69d6e285739a79dafe37caa736e52da4eb79e58c4a4935030007272a2d952676` | **none** (Jun 2017) | 8.1.0 | root | 2026-10-19 |
| 1.4 | `sha256:a9fc93acfbc734827a72107bf7f759745a66ea61758863c094c36e5f4f4b810b` | `07c25982ec6db7f18fb20ffeb963e42f9ddc00e2` (from `org.label-schema.vcs-ref`) | 8.1.0 | root | 2026-10-19 |
| 1.5 | `sha256:88193b1092d70d8b0e38ea8aef69ae642366cde7be0b1bdb449f68bce51fc04d` | `89d74c87b404a4cd21739f921dca3ca96f47ab6c` | 8.1.0 | root | 2026-10-22 |
| 1.6 | `sha256:7326a73da03c660b50dc22ffb4ee54f1e5de239b5ffbd6926872e29e0a19e258` | `30a94ccdc2babbd2ded8f16b36d99f79c14c52be` | 13.6.0 | node | 2026-10-19 |
| 1.7 | `sha256:b5b35951d49faeb4844d90d749513acdec96485fa3ebb9d41492dcaa71254a30` | `83bfa16643301b356c72d7ab86af92fe766017bd` | 13.6.0 | node | 2026-10-22 |
| 1.8 | `sha256:6516f998c9ab0c5be8a24e4d696ec1e818ede3ec5a0710e8ff5115f0ed89e3b4` | `6c4454f1f19fffdfa39fb855026d581b185343d6` | 13.6.0 | node | 2026-10-22 |
| 1.9 | `sha256:be6b5ba3abdca6e01689e0d1d27b41410fb5bf5793da407108a89ef355f362f0` | `0ec53bfee741ae3bffb5936f1c44138d7d4a3006` | 13.6.0 | node | 2026-10-22 |
| 1.10.0 | `sha256:08e951b9a5c4890740d2291a0f95782aca2b559bf18fb9e2a76d2146225af8b1` | `09c24b19bebb08f052ae939eafc1afb9184fc41a` | 15.13.0 | node | 2026-10-22 |
| 1.10.1, `1.10`, `1` | `sha256:2ad94733189b30844049caed7e17711bf11ed9d1116eaf10000586081451690b` (one image, three tags) | `913ea7222259ac48ffe1785f690427c4d98bd51a` | 16.10.0 | node | 2026-10-22 |

All images are `linux/amd64` only and start with `npm start` from `/usr/src/app`.

A few things stood out:
- **The 1.9 image doesn't match the git tag.** The label says `0ec53bf`, but git tag `v1.9.0` points at `ec7bf64`. The only difference between them is one README line, so it doesn't matter in practice, but trust the label. Only v1.9.0, v1.10.0 and v1.10.1 have git tags at all.
- **There's no source for 1.0–1.3.** Those images predate the repo's history (first commit is 2017-10-06), so you can't branch from them.
- **1.0–1.6 were all last pulled within about 6 seconds of each other on 10-19.** That looks like a scanner or mirror sweeping the repo, not real users. Real daily traffic is on 1.5 (AWS CDK) and 1.7 onwards.
- **1.0–1.5 run as root**, including the 1.5 image that the AWS CDK docs use. Mention this in the notice.

## Deprecation images for the old tags

The proposal: overwrite each old tag with an image that shows a deprecation warning and points to the upgrade. That's a sound approach. It reaches people who will never read a README, and Docker's own official images rebuild existing tags all the time. How to do it safely:

**1. Add a layer on top of the published image instead of rebuilding from each commit.** Use a small Dockerfile per tag:

```dockerfile
FROM paulbouwer/hello-kubernetes:1.5@sha256:88193b1092d70d8b0e38ea8aef69ae642366cde7be0b1bdb449f68bce51fc04d
COPY deprecation/ /usr/src/app/   # patched views/layouts/main.handlebars + a startup notice
LABEL org.opencontainers.image.description="DEPRECATED: unsupported, insecure. Upgrade to paulbouwer/hello-kubernetes:1.11 or later." \
      io.github.paulbouwer.hello-kubernetes.deprecated="true"
```

Rebuilding from a 2017–2021 commit is risky: the old base images and npm dependencies may no longer install, and anything that does build may behave subtly differently. A layer changes only what you add. It also works for 1.0–1.3, which have no source. Every image keeps `/usr/src/app` as its working directory, but the template files differ between versions, so each one needs its own patch. Branches from the commits are still useful for history. A light way to keep that is annotated git tags such as `image/1.5` → `89d74c8`, plus one `deprecation/` folder on `main` holding all the per-tag Dockerfiles.

**2. Keep behaviour exactly the same apart from the warning.** Many users have automation built on this image. The 42-school graders, tutorials and probes `curl` the page and look for the message text.
- Keep the same port, `/` path, environment variables, message text and exit behaviour.
- Add the warning as a separate banner above the existing content, written inline with no external CSS or images.
- Print one clear notice to stdout on startup, so it shows in `kubectl logs`.
- Never add a startup delay or deliberate failures ("brownouts"). Those break things like the AWS CDK quick start.

**3. Keep the originals reachable.** Before overwriting, retag each original as `1.5-original` (and so on), so the old digest stays tagged and Docker Hub won't clean it up. Anyone who needs the exact old image can pin the digest above. Publish this table in the deprecation notice.

**4. Don't put the warning on `1` and `1.10`.** Move those tags to the real 1.11 fix, so people on those tags get the fix instead of a warning. Overwrite 1.10.1 and earlier with the warning versions.

**5. Order matters:**
1. Ship 1.11 first, so the warning has something to point to.
2. Announce it with a date: Docker Hub overview, a pinned issue, the README, and the upstream PRs to AWS CDK and the others.
3. Publish the warning images, starting with the barely used 1.0–1.6.
4. Watch for issues, then do 1.7–1.10.1.

**Caveats:**
- People with the image already cached and `imagePullPolicy: IfNotPresent` won't see the warning until a node pulls again. Anyone pinned by digest won't see it at all. That's acceptable. The goal is to reach new users, especially people following old tutorials.
- The warning images still contain the vulnerable Node and OS packages. They're a pointer to the upgrade, not a fix, so the banner should say "insecure, upgrade now", not "patched".
- Changing published tags is a one-way, public action. Write the plan into a `deprecation.md` and sign off on it before anything is pushed.
- Test each warning image on kind before publishing (see [testing.md](testing.md)): the page still returns 200 at `/`, the original message text is still present, and probes pass.

The eMudhra details come from news coverage and Endor Labs, not Node's own release notes. Check the Node.js 21 October security release before quoting version numbers in your notice.

Sources:
- [Endor Labs: eMudhra intermediate CA compromise](https://www.endorlabs.com/learn/emudhra-intermediate-ca-compromise-the-trust-stores-you-patched-and-the-ones-you-didnt-know-you-had)
- [The Hacker News: Eight eMudhra CA keys compromised](https://thehackernews.com/2026/10/eight-emudhra-ca-keys-compromised.html)
- [BleepingComputer: Mozilla, Google, Apple block eMudhra certs](https://www.bleepingcomputer.com/news/security/mozilla-google-apple-block-compromised-emudhra-ca-certificates/)
- [Red Hat RHSB-2026-012](https://access.redhat.com/security/vulnerabilities/RHSB-2026-012)
- [UlisesGascon gist: root store check](https://gist.github.com/UlisesGascon/10ed0724930e5382b3ed48fa2b0d3e02)
- [paulbouwer/hello-kubernetes](https://github.com/paulbouwer/hello-kubernetes)
- [Docker Hub: paulbouwer/hello-kubernetes](https://hub.docker.com/r/paulbouwer/hello-kubernetes/)
