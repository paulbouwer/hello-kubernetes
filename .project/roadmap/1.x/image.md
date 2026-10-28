---
title: Container image
description: Node over Bun, base image, debugging with kubectl debug, amd64 and arm64 only, showing the architecture, and vulnerability scanning.
type: plan
status: active
areas: [image, app]
created: 2026-10-22
updated: 2026-10-28
---

# Container image

Choices for the hello-kubernetes image: runtime, base image, architectures, debugging and vulnerability scanning. This builds on item 1 (base image), item 3 (workflows) and item 5 (Dependabot) in [review.md](review.md).

## Summary

- **Stay on Node**, not Bun.
- **Move to `node:24-alpine` first**, pinned by digest, as item 1 in the review says. It clears the old CVEs and keeps a shell.
- **Consider Google distroless (`nodejs24-debian13:nonroot`) for a 2.x major release**, documenting `kubectl debug` for anyone used to `kubectl exec`.
- **Ship amd64 and arm64 only**, as set out in [GOAL.md](../../GOAL.md). Other architectures are out of scope until a possible 2.0 rewrite in Go or Rust.
- **Keep Trivy**, installed as a checksum-verified release or a SHA-pinned action, make it fail the build on fixable HIGH and CRITICAL findings, and add Dependabot and CodeQL around it.

## Runtime: Node, not Bun

The app is an 81-line Express server with five dependencies. Bun's advantages (faster startup and installs, bundling, built-in TypeScript) make no real difference to it.

- **Predictable support.** The root problem in the review is an image left on end-of-life Node 16. Node has LTS releases with published end-of-life dates and coordinated security releases. Bun has no LTS line, so staying patched means following its latest releases, which is harder for an occasionally maintained repo.
- **Fewer surprises.** Express, pino and handlebars run on Bun, but Bun re-implements Node's APIs, and edge cases appear in places like logging and streams.
- **A familiar teaching example.** People mostly use this repo to learn Kubernetes, and `node server.js` is what they expect.

Bun is worth another look only if the app is rewritten in TypeScript and the goal is to drop the build step.

### Dependency upgrades

Worth more than a runtime change. All are major versions, so test routes and logging afterwards (the e2e tests in [testing.md](testing.md) help):

- Express 4 → 5
- `express-pino-logger` → `pino-http` (`express-pino-logger` is no longer maintained, and `pino-http` replaces it)
- pino 6 → 9
- `express-handlebars` 5 → current

Also commit a `package-lock.json`. The repo doesn't have one, and `npm ci` and Dependabot's npm updates need it.

Done in #75 (the lockfile) and #77 (the upgrades): Express 5.3.0, express-handlebars 9.0.2, pino 10.4.0 and pino-http 11.0.0, with the unused direct `handlebars` dependency removed. Every version was published at least 7 days before it was chosen (`npm install --before`), the cooldown that AGENTS.md now sets. #77 also added a SIGTERM and SIGINT handler, so the container stops in about 0.2 seconds instead of being killed after the grace period.

## Base image

### Step 1: `node:24-alpine`

Review item 1: `node:24-alpine` (≥24.22.1, pinned by digest), multi-stage `npm ci --omit=dev`, numeric `USER 1000`, and `CMD ["node","server.js"]` so npm isn't in the startup path.

Done in #75, with two additions:

- **The lockfile was ignored.** `.gitignore` and `src/app/.dockerignore` both listed `package-lock.json`, so it could never be committed or used in a build. Both lines are removed, and the lockfile is committed.
- **npm, corepack and Yarn are removed from the runtime image.** The app no longer runs them, and npm's bundled dependencies (`undici`, `brace-expansion`) were the only fixable HIGH findings left. With them removed, Trivy finds no vulnerabilities at any severity. The build stage still uses npm for `npm ci`.

The image still stops slowly: `node` is PID 1 with no SIGTERM handler, so it waits for the grace period. 2.2 adds a handler.

### Step 2 (optional, 2.x): distroless

A distroless image has no shell or package manager, which removes most of the OS packages that show up in scans. Options checked against the registries:

| Image | Platforms published | Free? | Notes |
|---|---|---|---|
| **Google distroless** `gcr.io/distroless/nodejs24-debian13` | amd64, arm64, ppc64le, s390x | Yes, no login | Has `:nonroot` and `:debug-nonroot` tags (debug adds a busybox shell at `/busybox/sh`). Entrypoint is already `node`. |
| **Chainguard** `cgr.dev/chainguard/node` | amd64, arm64 | Only `:latest` | Fewest CVEs, but there's no free `:24` tag, so you'd move with every Node release. |
| **Docker Hardened Images** `dhi.io/node` | Couldn't check | Free since late 2025 (from memory; check) | Anonymous pulls are refused (401), so everyone building the image needs a Docker login. |

**Recommended: `gcr.io/distroless/nodejs24-debian13:nonroot`.** Changes needed in the Dockerfile:

- **Two stages.** `npm ci --omit=dev` in `node:24-*`, then copy `node_modules` and the app into the distroless image, which has no npm.
- **`CMD ["server.js"]`**, because the entrypoint is already `node`.
- **User ID.** `:nonroot` runs as 65532, while the review and #35 plan for 1000. Either set `USER 1000` (Node doesn't need a passwd entry) or use 65532 everywhere. Make the chart's `runAsUser` and E7 in `testing.md` match.
- **Pin by digest** and let Dependabot update it. Node patch releases arrive through rebuilds under the same tag, so they can trail the official `node` image slightly.

Do this in a major version, since it removes the shell.

## Debugging without a shell

No tutorial that relies on `kubectl exec` into this image has been found. The uses found in the review (AWS CDK quick start, cdk8s examples, the DigitalOcean tutorial, 42-school projects) all `curl` the page from outside the pod, and a GitHub code search for `hello-kubernetes` with `kubectl exec` or `-- sh` returned nothing. That suggests it's rare, though code search is too coarse to rule it out.

One confirmed case: E7 in `testing.md` runs `kubectl exec ... -- id -u`, which needs an `id` binary. With distroless, check the user instead by asserting `runAsUser` in the pod spec and relying on restricted Pod Security admission passing.

### Use `kubectl debug`, not a sidecar

A sidecar with a shell would work technically (shared network, and `shareProcessNamespace: true` exposes the app's processes and files), but:

- **It undoes the point of distroless.** The shell image runs in every pod and has to be patched and scanned.
- **It doesn't help tutorials.** `kubectl exec deploy/hello-kubernetes -- sh` lands in the container named by the `kubectl.kubernetes.io/default-container` annotation. If that's the app, there's no shell. If it's the sidecar, `env` and `printenv MESSAGE` show the sidecar's variables, not the app's.
- **It adds memory and complexity** to an app meant to be the simplest possible example.

Kubernetes already provides a temporary (ephemeral) debug container, enabled by default on recent clusters including kind and k3s:

```bash
kubectl debug -it <pod> --image=busybox --target=hello-kubernetes -- sh
```

It shares the pod's network, and with `--target` it sees the app's processes (`ps`, `cat /proc/1/environ`). It stays as a stopped entry in the pod spec until the pod is replaced. Document this in the README if the image goes distroless.

## Architectures

Platforms published, checked against the registries in October 2026:

| Image | amd64 | arm64 | arm/v7 | riscv64 |
|---|---|---|---|---|
| `node:24-alpine` | ✓ | ✓ | ✗ | ✗ |
| `node:24-slim` | ✓ | ✓ | ✗ | ✗ |
| `gcr.io/distroless/nodejs24-debian13` | ✓ | ✓ | ✗ | ✗ |
| `gcr.io/distroless/cc-debian13` (no runtime) | ✓ | ✓ | ✓ | ✓ |
| Chainguard `node` | ✓ | ✓ | ✗ | ✗ |

### Supported: amd64 and arm64

[GOAL.md](../../GOAL.md) limits the image to platforms with official Node runtime images: `linux/amd64` and `linux/arm64`. Every candidate base image above publishes both.

The page shows the image's architecture. Today it reads it from `src/app/info.json`, which is hard-coded to `linux/amd64`, so an arm64 image would report the wrong architecture. From 1.11 the app reads it at runtime instead, from `process.platform` and `process.arch`, as PR #40 did, and `info.json` is removed (decided 2026-10-26):

- **It shows the image, not the host.** `process.arch` is fixed when the Node binary is built, so an amd64 image running under emulation on an arm64 node shows `linux/amd64`. That's correct for "the image's architecture", and it makes emulation visible.
- **Map Node's names to OCI names**, so the page matches image manifests and the `kubernetes.io/arch` node label: `x64` → `amd64`. `arm64` is the same in both.
- **Don't use `os.machine()`.** It comes from the kernel (`uname -m`), so it reports the host, and QEMU user-mode emulation can fake it.
- **No build step is needed**, so local builds on any platform report correctly too.

The kernel line on the page (`os.type()` and `os.release()`) does come from the host kernel, and can look unusual in some environments. These are correct, not bugs: Docker Desktop shows its VM kernel (`…-microsoft-standard-WSL2` on Windows, `…-linuxkit` on macOS), gVisor shows its own kernel version, and Kata or Firecracker show the guest VM's kernel.

### Out of scope until 2.0

`linux/arm/v7`, `linux/riscv64`, `linux/ppc64le` and `linux/s390x` are out of scope for 1.x. The findings behind that decision:

- **arm/v7:** upstream Node stopped shipping 32-bit Arm builds, so no Node 24 image has `linux/arm/v7`, whichever base is used. Raspberry Pi users need a 64-bit OS (Pi 3, 4 and 5 support it).
- **riscv64:** official Node 24 releases have no riscv64 build. The Node project's unofficial-builds site has one, and distroless `cc-debian13` publishes riscv64, so a custom Dockerfile could combine them. But that means pinning Node by hand outside Dependabot, a weaker download check than official releases, and best-effort timing on security releases. Not worth it for 1.x.

Update the multi-arch notes in [community.md](community.md) (the `linux/arm/v7` and `linux/riscv64` plans from #46) and the reply on #16 to match.

A possible 2.0 rewrite in Go or Rust would remove the dependency on Node's platform support. Both compile to static binaries for arm/v7 and riscv64, which would run on `gcr.io/distroless/static-debian13` (it publishes amd64, arm64, arm/v7, riscv64, ppc64le and s390x).

## Vulnerability scanning

### What GitHub provides

- **Dependabot alerts and security updates** cover the npm dependencies in `src/app/package.json`. Free; turn them on, plus `dependabot.yml` for npm, docker and github-actions (review item 5). Done in #73, with the devcontainer as well. GitHub reads `dependabot.yml` only from `main`, so version updates start when 1.11 merges.
- **CodeQL code scanning** finds vulnerable patterns in the JavaScript source. Free for public repos; enable the default setup. Done in #73, for JavaScript/TypeScript and Actions.
- **Nothing in GitHub scans the OS packages inside an image.** Code scanning only displays results from other tools. The current alerts (zlib, busybox, OpenSSL) are all OS packages, so an external scanner is still needed.

### Trivy, installed safely

Trivy is still a reasonable choice. But in March 2026, attackers force-pushed malicious code to most version tags of `aquasecurity/trivy-action` and `setup-trivy`, and published a compromised Trivy release. Workflows referencing the action by tag ran a credential stealer; workflows pinned to a commit SHA weren't affected. (From memory: check Aqua's advisory for the exact versions and tags before choosing one.)

That changes review item 3 ("the `trivy-action` (pinned)"). Either:

- download a specific Trivy release from after the incident and **verify its checksum**, or
- use the action pinned to a **commit SHA** of a post-fix version, never a tag.

The current workflow downloads Trivy 0.19.2 with no checksum check, and that version is far too old to catch current CVEs. The devcontainer installed the same version until #50; it now installs the latest Trivy 0.x release, checked against the release's checksum file.

### Alternatives

- **Grype** (Anchore, via `anchore/scan-action`) is the closest swap: same job, SARIF output, similar false-positive rate. An equal choice rather than an upgrade, and it needs the same SHA pinning.
- **Docker Scout** fits Docker Hub publishing, but the free tier is limited.

### Stopping the image going stale again

The scanner was never the root cause. The base image sat on an end-of-life Alpine for years and nothing failed. In order of impact:

1. **Dependabot with the `docker` ecosystem**, so base-image bumps arrive as PRs.
2. **Make the scan fail the build** with `--severity HIGH,CRITICAL --ignore-unfixed --exit-code 1` (I4 in `testing.md`). Today it uploads results and always passes.
3. **Expect scheduled runs to stop.** GitHub disables scheduled workflows after 60 days with no repository activity, which is what turned the scan off in August. Merging Dependabot PRs counts as activity. Also run the scan on PRs, not only on the schedule.
4. Optionally, generate an SBOM (`anchore/sbom-action`) and build provenance (`actions/attest-build-provenance`), which the review notes are missing.
