---
title: Community contributions — triage and credits
description: Triage of open issues and PRs, what to merge, incorporate or close, and how to credit contributors.
type: review
status: final
areas: [app, image, deploy]
created: 2026-10-22
updated: 2026-10-23
---

# Community contributions — triage and credits

A review of every open issue and pull request (plus a few closed ones that are still relevant), deciding what to close, what to fold into the 1.11 / 2.0 modernisation work (see [review.md](review.md)), and who deserves credit. Most of these were raised in 2021–2023 and went unanswered; several people correctly diagnosed problems this release now fixes.

## Summary

| Item | Raised by | Decision | Lands in (review row) |
|---|---|---|---|
| PR #30 probe paths with ingress prefix | @khetho | **Merge as-is** (keeps authorship), closes #44 | #6 Helm |
| Issue #44 probes fail with `pathPrefix` | @ngaffa | Close via PR #30 | #6 Helm |
| Issue #35 `runAsNonRoot` fails, non-numeric user | @Alestrix | **Incorporate**: numeric UID 1000 + chart `securityContext` | #1 base image, #6 Helm |
| PR #40 multi-arch (amd64/arm64), GHCR, metadata-action | @MrRoundRobin | **Incorporate in spirit**, then close | #4 publishing |
| PR #46 multi-arch incl. arm/v7 + riscv64, numeric user | @chazapis | **Incorporate in spirit** (amd64/arm64 only; arm/v7 and riscv64 out of scope until 2.0), then close | #4 publishing, #1 |
| Issue #16 `exec format error` on Raspberry Pi (closed) | @MichaelMichaelMichaelMichaelMichael | Comment when arm64 ships (needs a 64-bit OS on the Pi) | #4 publishing |
| PR #45 base image update | @NikolaiThingnesLeira | **Close as superseded** (still Node 16, EOL) | #1 base image |
| Issue #38 asset paths break when `RENDER_PATH_PREFIX` unset | @hotspoons | **Incorporate**: fix template path handling | new: app fix |
| Issue #31 ingress example broken on `networking.k8s.io/v1` | @kimllee | **Incorporate**: chart creates the Ingress/HTTPRoute; rewrite ingress doc with NGINX and Traefik examples | #6 Helm / docs |
| Issue #28 how to remove the deployment | @simonw | **Incorporate**: uninstall step in README quick start | docs |
| Issue #29 single-file manifest (closed) | @STRRL | **Revisit**: publish rendered manifest as a release asset | #4 publishing |
| Issue #23 is this on Artifact Hub? | @weironz | **Incorporate (optional)**: publish OCI chart + Artifact Hub listing, or close with answer | #4 publishing |
| PR #41 replicas 2 → 3 | @szairi2011 | **Close** with thanks (personal values; use `--set`) | — |
| PR #43 custom message + 6 replicas | @szairi2011 | **Close** with thanks (personal values; use `--set`) | — |
| PR #48 "Create test.txt" (unrelated FastAPI service) | @maddy00o7 | **Close** as off-topic, label `invalid` | — |

## Detail

### Merge

**PR #30 — Catered for liveness and readiness probe when ingress supplied** (@khetho, Dec 2021)
Correct, minimal and still mergeable. When `ingress.configured` is true and `rewritePath` is false, probes hit `/<pathPrefix>` instead of `/`. Merge it directly so the commit stays Khetho's, then build the other chart changes on top, including the move to top-level `pathPrefix`/`rewritePath` in [deploy.md](deploy.md), which keeps the same probe behaviour. Close #44 as fixed by it.

**Issue #44 — Readiness and liveness probes fail with pathPrefix** (@ngaffa, May 2023)
Same bug as PR #30, independently reported. Credit @ngaffa alongside @khetho in the release notes. Ngaffa's comment on #38 with a working nginx-ingress workaround is also worth acknowledging.

### Incorporate in spirit

**Issue #35 — Not working when `runAsNonRoot` is set** (@Alestrix, Jul 2022)
Accurate diagnosis: `USER node` is a name, so the kubelet can't verify non-root. Fix in two places: `USER 1000:1000` in the Dockerfile, and a default pod/container `securityContext` in the chart (`runAsNonRoot: true`, `runAsUser: 1000`, `readOnlyRootFilesystem: true`, `allowPrivilegeEscalation: false`, `capabilities.drop: [ALL]`, `seccompProfile: RuntimeDefault`).

**PR #40 — Multi arch support** (@MrRoundRobin, Jan 2023) and **PR #46 — Build multi-arch images locally, including ARM and RISC-V** (@chazapis, Jul 2023)
Both are the right idea, but the actions they use are now several majors old and both rebase onto Node 16/19. Rather than merging, rebuild the publish workflow and credit both via `Co-authored-by` trailers. Ideas to carry over:
- From #40: `docker/metadata-action` for tags, `setup-qemu` + `setup-buildx`, publishing to **GHCR as well as Docker Hub**, and making the page show the real architecture. #40 did that by replacing `info.json` with `os.platform() + '/' + os.arch()` in `server.js`; [GOAL.md](../../GOAL.md) instead has CI write `info.json` for each platform at build time.
- From #46: a numeric UID 1000 user (also fixes #35) and a `make` target for local multi-arch builds. Its wider platform list (`linux/arm/v7`, `linux/riscv64`) is out of scope: [GOAL.md](../../GOAL.md) limits 1.x to `linux/amd64` and `linux/arm64`, the platforms with official Node runtime images. Node 24 has no arm/v7 build and only an unofficial riscv64 one (details in [image.md](image.md)). Explain this when closing, and mention that a possible 2.0 rewrite in Go or Rust could bring them back.

Close both with a comment linking the replacement PR.

**Issue #16 — exec format error on Raspberry Pi** (@MichaelMichaelMichaelMichaelMichael, Jan 2021, closed)
Closed, but the root cause (amd64-only images) was never fixed. @vorburger diagnosed it in the thread, and @rthrprnt asked again in June 2025 about an Apple M1. When arm64 ships, comment there so the people who asked find out. Say that a Raspberry Pi needs a 64-bit OS (Pi 3, 4 and 5 support one), since 32-bit `arm/v7` images are out of scope.

**Issue #38 — Unstyled content and missing images when `RENDER_PATH_PREFIX` is unset** (@hotspoons, Sep 2022)
`main.handlebars` builds asset URLs as `{{ renderPathPrefix }}/css/main.css`, so with an empty prefix the browser requests `/css/main.css` from the domain root, which fails when the app is served under a sub-path that isn't rewritten. Use relative asset URLs (`css/main.css`) when no prefix is set, or normalise the prefix as suggested. Credit @hotspoons for the diagnosis.

**Issue #31 — Ingress example not working** (@kimllee, Jan 2022)
`docs/deploy-with-ingress.md` still uses `networking.k8s.io/v1beta1`, which Kubernetes removed in 1.22. The fix is now bigger than the doc: the chart will create the Ingress (`networking.k8s.io/v1`, with `ingressClassName` and `pathType`) and a Gateway API HTTPRoute, as set out in [deploy.md](deploy.md). Rewrite the doc around that, with NGINX and Traefik as the two worked examples. @frayos posted a working v1 example in the thread, so use it as the starting point and credit them. @dcorbe's point that ingress config is cluster-specific is fair, and it's why [deploy.md](deploy.md) proposes no rewrite as the chart default: that works on any controller without annotations, and only rewriting needs controller-specific settings. Don't base the example on the community Ingress-NGINX controller, which was retired in March 2026.

**Issue #28 — Document how to delete the deployment** (@simonw, Oct 2021)
`helm uninstall` is documented in `docs/deploy-using-helm.md` but not in the README quick start, where newcomers look. Add a two-line "Clean up" step (`helm uninstall` + `kubectl delete namespace hello-kubernetes`). Credit @simonw, and @dcorbe for answering in the thread.

**Issue #29 — Please provide a single-file YAML** (@STRRL, Dec 2021, closed)
Closed with "run `helm template`", but the request is more relevant now: much of the usage found in the review (42-school projects, tutorials) is plain `kubectl apply`. Render the chart with `helm template` in the release workflow and attach `hello-kubernetes.yaml` to each GitHub release, so `kubectl apply -f https://github.com/paulbouwer/hello-kubernetes/releases/latest/download/hello-kubernetes.yaml` works. Credit @STRRL.

**Issue #23 — Is it on Artifact Hub?** (@weironz, Aug 2021)
The `opsmx/hello-kubernetes` chart on Artifact Hub is unofficial. Optional but cheap once the publish workflow is rebuilt: push the chart as an OCI artifact to `ghcr.io/paulbouwer/charts/hello-kubernetes` and register it on Artifact Hub as the official listing. If you don't want to maintain that, close the issue with a pointer to the in-repo chart.

### Close

**PR #45 — Update base image to resolve vulnerabilities** (@NikolaiThingnesLeira, Jun 2023)
Right instinct, but it moves to `node:16.20.0-alpine3.18`, which is also end-of-life. Close as superseded by the Node 24 update, and thank Nikolai in the release notes for flagging it, since they were the first to send a fix for the stale base image.

**PR #41 — Update values.yaml** and **PR #43 — Patch3** (@szairi2011, Apr 2023)
These change the default replica count and message for one person's deployment. Close with a friendly note that `--set deployment.replicaCount=6 --set message="..."` does the same without forking the chart.

**PR #48 — Create test.txt** (@maddy00o7, Feb 2025)
Adds an unrelated FastAPI service, a root Dockerfile and a CI workflow. Close as off-topic and label it `invalid` (see [operations.md](operations.md)).

## How to give credit

1. **Commit trailers.** Where a commit carries someone's idea or code forward, add `Co-authored-by:`. GitHub then shows them as a co-author and the commit counts on their profile:

   ```
   Co-authored-by: Robin Müller <948771+MrRoundRobin@users.noreply.github.com>
   Co-authored-by: Antony Chazapis <1699013+chazapis@users.noreply.github.com>
   Co-authored-by: Alestrix <7452860+Alestrix@users.noreply.github.com>
   Co-authored-by: Rich Siomporas <851973+hotspoons@users.noreply.github.com>
   Co-authored-by: Younes <33893234+frayos@users.noreply.github.com>
   Co-authored-by: Zhiqiang ZHOU <20221408+STRRL@users.noreply.github.com>
   Co-authored-by: Nikolai Thingnes Leira <8503265+NikolaiThingnesLeira@users.noreply.github.com>
   ```

   PR #30 is merged directly, so @khetho keeps authorship without a trailer.

2. **Release notes.** Add a "Thanks" section to the 1.11.0 / 2.0.0 release:

   > This release picks up fixes and ideas the community sent in while the project was quiet. Thank you, and sorry it took so long:
   > - @khetho and @ngaffa — Helm probes with an ingress path prefix (#30, #44)
   > - @Alestrix — `runAsNonRoot` support (#35)
   > - @MrRoundRobin and @chazapis — multi-arch images (#40, #46), with diagnosis and follow-ups from @vorburger, @MichaelMichaelMichaelMichaelMichael and @rthrprnt (#16)
   > - @NikolaiThingnesLeira — flagging the outdated base image (#45)
   > - @hotspoons — asset paths without a render prefix (#38)
   > - @kimllee and @frayos — `networking.k8s.io/v1` ingress example (#31), with input from @dcorbe
   > - @simonw — clean-up instructions (#28)
   > - @STRRL — single-file manifest (#29)
   > - @weironz — official chart listing (#23)

3. **A comment on each item when you close it**, linking the PR or release that resolves it. Something like: "Thanks for this — it took far too long, but it's fixed in 1.11.0 (#NN), and you're credited in the release notes." That notifies the original author directly, which the release notes alone won't.

## Contributor reference

| GitHub | Name | ID | Items |
|---|---|---|---|
| @khetho | Khetho Mtembo | 1104794 | PR #30 |
| @ngaffa | Naoufal El Gafa | 6530732 | #44, comment on #38 |
| @Alestrix | — | 7452860 | #35 |
| @MrRoundRobin | Robin Müller | 948771 | PR #40 |
| @chazapis | Antony Chazapis | 1699013 | PR #46 |
| @NikolaiThingnesLeira | Nikolai Thingnes Leira | 8503265 | PR #45 |
| @hotspoons | Rich Siomporas | 851973 | #38 |
| @kimllee | — | 29163814 | #31 |
| @frayos | Younes | 33893234 | working example on #31 |
| @dcorbe | Daniel Corbe | 2617758 | answers on #28, #29, #31 |
| @simonw | Simon Willison | 9599 | #28 |
| @STRRL | Zhiqiang Zhou | 20221408 | #29 |
| @weironz | will | 33590311 | #23 |
| @MichaelMichaelMichaelMichaelMichael | — | 4020552 | #16 |
| @vorburger | Michael Vorburger | 298598 | diagnosis on #16 |
| @rthrprnt | — | 17812864 | follow-up on #16 |
| @szairi2011 | — | — | PR #41, #43 (closed, no credit needed) |
| @maddy00o7 | — | — | PR #48 (closed as off-topic) |
