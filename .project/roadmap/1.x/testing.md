---
title: Testing
description: Image tests and e2e scenarios on kind (NGINX) and k3d (Traefik), Gateway API, the CI matrix and running locally.
type: plan
status: active
areas: [ci]
created: 2026-10-22
updated: 2026-10-29
---

# Testing

How to check hello-kubernetes against real Kubernetes clusters, locally and in CI. This goes with the modernisation work in [review.md](review.md): most fixes there (non-root, probes, ingress paths, multi-arch, LoadBalancer defaults) can only be proven by deploying to a cluster, and a passing unit test wouldn't show them. The scope being tested is set by [GOAL.md](../../GOAL.md), and the chart changes (chart-created Ingress and HTTPRoute, `pathPrefix`/`rewritePath`) by [deploy.md](deploy.md).

Two local cluster tools run entirely in containers:

- **kind** (Kubernetes in Docker): upstream Kubernetes, with the NGINX ingress controller, NGINX Gateway Fabric and a load balancer added by us. The main target.
- **k3d** (k3s in Docker): Rancher's lightweight distribution, with **Traefik** (Ingress and Gateway API) and the **ServiceLB** load balancer built in. The second target.

Between them, the two clusters cover the two worked examples in `deploy.md`: NGINX on kind and Traefik on k3d.

## Why both

**kind** is close to upstream Kubernetes and works with any Kubernetes version, so it's the reference for "does this work on Kubernetes". It covers most of what the fixes need to prove:

| What to test | How on kind |
|---|---|
| Your locally built image, without pushing to a registry | `kind load docker-image paulbouwer/hello-kubernetes:1.11.0` |
| #35 `runAsNonRoot` and the new `securityContext` | Label the namespace `pod-security.kubernetes.io/enforce=restricted`. Pods that break the rules are rejected at admission time. That's a much stricter check than #35's company policy. |
| #30/#44 probes and #38 asset paths behind a sub-path | Install F5's NGINX Ingress Controller using kind's port-mapping setup, then deploy with `ingress.enabled=true`, `pathPrefix` set and `rewritePath=false` (no rewrite, the recommended setting). |
| #31 ingress docs on `networking.k8s.io/v1` | The same NGINX setup. Run the doc's commands exactly as written. |
| Gateway API (chart-created HTTPRoute) | Install the Gateway API CRDs and NGINX Gateway Fabric, create a `Gateway`, then deploy with `httpRoute.enabled=true`. |
| `service.type: LoadBalancer` (old issues #1/#14, "EXTERNAL-IP pending") | Run `cloud-provider-kind` alongside the cluster so LoadBalancer services get an IP. |
| Pods spread across nodes (the page shows the node name) | A multi-node cluster: 1 control plane and 2 workers. |
| Older Kubernetes versions | Pick older Kubernetes versions with `--image kindest/node:<version>`. |
| CI | `helm/kind-action` plus `helm/chart-testing` in GitHub Actions, so every PR installs the chart and runs `helm test`. |

**k3d/k3s** matters because a large share of current users run k3s. The 42-school "Inception-of-Things" projects from the code search are built on k3s/k3d, and their part 2 is usually several hello-kubernetes apps behind an ingress. Raspberry Pi and home-lab users (issue #16) mostly run k3s too. k3s would catch problems kind won't:

- path-prefix behaviour under Traefik rather than NGINX, for both Ingress and HTTPRoute
- a LoadBalancer service working with no extra setup.

It's also a fast way to test arm64 on Apple Silicon or a Pi.

I'd skip minikube. It overlaps with kind and adds nothing for this app.

### What these won't cover

- **Cloud-specific behaviour**, such as an EKS LoadBalancer for the AWS CDK users. Testing there needs a real cluster; do it by hand before a major release if at all.
- **Other Ingress controllers and Gateway API implementations.** NGINX and Traefik are the documented examples; the no-rewrite path works on any controller without annotations, so it doesn't need testing on each.

Windows and architectures other than amd64 and arm64 (arm/v7, riscv64, ppc64le, s390x) are out of scope ([GOAL.md](../../GOAL.md)), so there's nothing to test for them.

## Test layers

1. **Image tests**: run the container directly, no cluster. Fast, run on every push.
2. **Chart tests**: render the chart with `helm template`, no cluster. Fast, run in each e2e job.
3. **End-to-end (e2e) tests**: install the chart (and the plain manifest) on kind and k3d, then check behaviour over HTTP and through the Kubernetes API. Run on every PR.
4. **Manual release checks**: k3d on a real arm64 machine, a quick look in a browser, and the docs read through once.

## Image tests

These check the image itself and guard against the problems found in the review coming back. All of them are in `test/image/run.sh` (`make test-image`): I1 to I3 from #75, I5a from #83, and I4 to I7 from #90. I4 fails, rather than skips, when Trivy is missing. I5 runs the image on its own platform by default, and on each platform in `PLATFORMS` when it is set. arm64 is checked on native arm64 runners in CI (3.3).

| ID | Check | How | Guards against |
|---|---|---|---|
| I1 | Node is a supported, patched version | `docker run --rm --entrypoint node IMG -p process.versions.node` ≥ the eMudhra-fixed release for that line (22.23.4 / 24.22.1 / 26.12.1) | Node 16 EOL, eMudhra |
| I2 | OS CA bundle is patched | `docker run --rm --entrypoint apk IMG list --installed ca-certificates-bundle` ≥ `20261020-r0`. The `node` Alpine images install `ca-certificates-bundle`, not `ca-certificates` (found in #75) | eMudhra (OS store) |
| I3 | Runs as numeric non-root user | `docker inspect -f '{{.Config.User}}' IMG` is `1000` or `1000:1000`; `docker run --rm --entrypoint id IMG -u` prints `1000` | #35 |
| I4 | No HIGH/CRITICAL vulnerabilities with a fix available | Trivy with `--severity HIGH,CRITICAL --ignore-unfixed --exit-code 1` | stale base image |
| I5a | The page shows the running image's architecture in OCI form | Added in #83. Run the image as it is, and check the footer against `docker inspect` (`Os/Architecture`). Then run it with `test/image/fake-arch.js` preloaded (`NODE_OPTIONS=--require`), which makes `process.arch` report `FAKE_ARCH`, and check `x64` → `amd64`, `arm64`, `ia32` → `386`, `ppc64` → `ppc64le`, `s390x` and `riscv64` | #40, #16 |
| I5 | Starts and serves on every published platform, and reports it correctly | For `linux/amd64` and `linux/arm64`: `docker run --platform <p> -d -p 8080:8080 IMG`, then `curl -fsS localhost:8080/` and check the page shows `<p>` as the architecture (proves the app reports each platform at runtime) | #16, #40 |
| I6 | Respects `PORT` | `docker run -e PORT=9090 -p 9090:9090 IMG` and `curl -fsS localhost:9090/` | #34 |
| I7 | Works with a read-only root filesystem | `docker run --read-only --tmpfs /tmp IMG` and `curl -fsS localhost:8080/` | chart `readOnlyRootFilesystem` default |

## Published images

`test/image/verify-published.sh` (`make verify-published PUBLISHED=…`), added in #102, checks a published image in a registry: one index for amd64 and arm64 (V1), an SBOM (V2) and provenance from this repo's CI (V3) for each platform, the signed attestation (V4), the user and labels (V5), and with `SCAN=1` a vulnerability scan (V6). Local images have no SBOM, provenance or signature, so they are checked with `make test-image` instead. 6.2 runs it on both registries after the release.

## Proxy tests

`test/proxy/run.sh` (`make test-proxy`), added in #81, runs the image behind an NGINX container and checks that the page and every asset it links to load through the proxy. It covers deployments that don't use the chart, which the e2e scenarios don't reach.

| ID | Proxy | Prefixes | Guards against |
|---|---|---|---|
| P1 | Serves the app at `/hello/` and strips the path | none | #38 |
| P2 | Passes `/hello/` through | `RENDER_PATH_PREFIX` and `HANDLER_PATH_PREFIX` both `/hello` | the chart's recommended setup breaking |
| P3 | Serves the app at `/hello/` and strips the path | both only `/` | asset URLs becoming `//css/…` |

## Chart tests

`test/chart/run.sh` (`make test-chart`), added in #115 and extended for the schema in #117, renders the chart with `helm template` and checks what it creates, with no cluster. It covers the cases that are slow or need a controller to test on a cluster: each way of exposing the app, the old value names, and odd values.

| ID | Values | Checks |
|---|---|---|
| C1 | defaults | No Ingress, no HTTPRoute, no prefix variables |
| C2 | `ingress.enabled`, `pathPrefix`, `rewritePath=false` | A `networking.k8s.io/v1` Ingress with the class, host, TLS and annotations; both prefixes set; probes under the prefix |
| C3 | `ingress.enabled`, `pathPrefix` | Only the render prefix set; probes at `/`; notes about the rewrite annotation and the service type |
| C4 | `httpRoute.enabled`, `pathPrefix` | A `gateway.networking.k8s.io/v1` HTTPRoute with the parent refs and host names, and a `URLRewrite` filter |
| C5 | `httpRoute.enabled`, `rewritePath=false` | No filter; probes under the prefix |
| C6 | `httpRoute.enabled` with no parent refs | The install fails with a clear message |
| C7 | the old `ingress.*` names | The same prefixes as before, and a deprecation note |
| C8 | `rewritePath=false` in the old or the new name | `false` wins |
| C9 | `app/hello`, `/app/hello`, `/app/hello/`, `/` | The same result; `/` means no prefix |
| C10 | quotes in the message and the prefix | `helm lint --strict` passes |
| C11 | the old `ingress.pathPrefix` alone | No prefix, as before |
| C12 | the defaults and the values of C2, C4 and others | The schema accepts them |
| C13 | an unknown key, a wrong type, a `service.type` or `pullPolicy` not allowed, a port out of range, a non-string annotation | The schema rejects each, and the error names the value |
| C14 | `--set message=42`, `--set-string message=42`; the image tag as the integer `1` from `--set`, the number `1.11` from a values file, a string, a pre-release, empty and unset | A number as the message is rejected; as a string it works. Each tag renders the right image and `CONTAINER_IMAGE`, with no `%!` formatting error (#131) |
| C15 | the old `ingress.*` names, `global` | The schema accepts them |
| C16 | `values.yaml` and `values.schema.json` | Every value has a description, and the schema has nothing `values.yaml` doesn't, except the old names and `global` |
| C17 | `docs/deploy-using-helm.md` | The values table lists every value in the schema, except `global` (#121) |

The schema (#117) is checked by C6 and C12–C16.

## End-to-end scenarios

Every scenario runs on both kind and k3d unless the "Clusters" column says otherwise. "Page" means the HTML returned by `GET /` (or `GET /<prefix>/`). The checks only use `kubectl`, `helm` and `curl`, so they behave the same locally and in CI.

| ID | Scenario | Setup | Pass criteria | Clusters | Covers |
|---|---|---|---|---|---|
| E1 | Default install | `helm install hello-world ./deploy/helm/hello-kubernetes -n hk-e1 --create-namespace --set service.type=ClusterIP --wait` | Deployment shows 2/2 ready. Through `kubectl port-forward svc/...`: page has `Hello world!`, the namespace `hk-e1`, a pod name and node name that match a real pod (`kubectl get pod -o jsonpath`), and the expected image tag | both | baseline |
| E2 | Page details are correct | same as E1 | The architecture shown matches the node's `kubernetes.io/arch` label | both | #40 |
| E3 | Custom message, escaped | `--set message='<b>Hi</b> & "you"'` | Install succeeds. Page has `&lt;b&gt;Hi&lt;/b&gt; &amp; &quot;you&quot;` and does **not** contain a raw `<b>Hi</b>` tag. Failed until 4.1 (#113), which quotes the message and `pathPrefix` | both | message injection, chart quoting bug |
| E4 | Custom port | `--set deployment.container.port=9090` | Pods become ready (probes follow the port), page served through the service | both | #34 |
| E5 | Ingress with rewrite | Two releases (`hello-world`, `custom-message`) with `ingress.enabled=true`, `rewritePath=true`, prefixes `/app/hello-world` and `/app/custom`, each with its own host. Controller-specific annotations: `nginx.org/rewrites` on kind; a Traefik `stripPrefix` Middleware on k3d | `curl http://localhost:<port>/app/hello-world/` and `/app/custom/` each return their own page; CSS and image links resolve (200) | both | #31 docs |
| E6 | Ingress without rewrite (recommended) | One release with `ingress.enabled=true`, `ingress.className` for the cluster, `pathPrefix=/app/hello`, `rewritePath=false`, no annotations | Pods **ready** (no probe failures in `kubectl get events`); page, `css/main.css` and `images/kubernetes.png` all 200 under `/app/hello/` | both | #30, #44, #38 |
| E7 | Restricted Pod Security | Namespace labelled `pod-security.kubernetes.io/enforce=restricted`, chart installed with defaults | Install succeeds with no admission warnings; pods run with `runAsUser: 1000`; `kubectl exec ... -- id -u` prints `1000` | both | #35 |
| E8 | LoadBalancer service | `--set service.type=LoadBalancer`. kind: `cloud-provider-kind`, which `cluster.sh` starts; k3d: built-in ServiceLB, on port 8080, because Traefik holds port 80 | Service gets an `EXTERNAL-IP` within 60s; page served through it | both | #1, #14 |
| E9 | Pods across nodes | `--set deployment.replicaCount=4` on a 1 control-plane + 2 worker cluster | Repeated requests through the service return at least 2 distinct pod names, and pods sit on at least 2 nodes | both | the demo's main point |
| E10 | Single-file manifest | `kubectl apply -f hello-kubernetes.yaml` (the rendered release asset), no Helm | Same checks as E1 | both | #29 |
| E11 | Clean uninstall | After E1: `helm uninstall hello-world -n hk-e1` then `kubectl delete ns hk-e1 --wait` | No Deployment, Service, ServiceAccount or pods left with the chart's labels | both | #28 |
| E12 | Rolling upgrade | Install with `message=v1`, then `helm upgrade --set message=v2 --wait` | All pods replaced, page shows `v2`, no downtime: a background `curl` loop during the upgrade sees no non-200 responses | kind | upgrades |
| E13 | Kubernetes version range | E1 + E6 + E7 on the oldest Kubernetes version the chart supports, 1.35 (the newest, 1.37, runs every scenario) | Same pass criteria | kind amd64, `E2E_KUBERNETES=oldest` (`make e2e-kind-oldest`) | API removals like #31 |
| E14 | arm64 nodes | E1 + E2 on an arm64 host | Architecture shown is `linux/arm64` | both, arm64 runner. Since 4.1, every scenario runs on arm64, and E2 checks the architecture | #16 |
| E15 | Docs still work | Run, in order, the blocks marked ```` ```bash e2e ```` in `README.md`, `docs/deploy-using-helm.md` and `docs/deploy-with-ingress.md`, with the local chart, image and release file in place of the published ones | Each block exits 0, and the docs' own clean-up steps remove everything | k3d, because the guides' examples use Traefik | stops #31 recurring |
| E16 | HTTPRoute with rewrite | Two releases with `httpRoute.enabled=true`, `parentRefs` pointing at the test `Gateway`, `rewritePath=true`, prefixes `/app/hello-world` and `/app/custom` | Same as E5, through the Gateway. The rendered HTTPRoute has a `URLRewrite` filter and no controller-specific settings | both | Gateway API scope |
| E17 | HTTPRoute without rewrite | One release with `httpRoute.enabled=true`, `pathPrefix=/app/hello` | Same as E6, through the Gateway; the HTTPRoute is `Accepted` in its status | both | Gateway API scope |
| E18 | Old value names still work | Install with the old `ingress.configured=true`, `ingress.pathPrefix`, `ingress.rewritePath` and a hand-written Ingress | Same as E6 or E5, depending on `rewritePath` | kind | migration to top-level `pathPrefix`/`rewritePath` |

E15 runs the blocks marked ```` ```bash e2e ````. GitHub still highlights them as bash. A marked block must run without input, and the blocks in a file must run in order. Leave a block unmarked when it runs until stopped (`port-forward`), needs a published release (the signature check), or needs another cluster (the NGINX example). Testing showed that a typo in a marked README command fails E15 and names the block (#123).

### Per-cluster setup

`test/e2e/cluster.sh` (#123) creates each cluster and sets up its Ingress controller and Gateway, so every routing scenario runs unchanged on both. It exports the Ingress class, the Gateway and the URL each one answers on.

| | kind | k3d |
|---|---|---|
| Ingress controller | F5 NGINX Ingress Controller 5.7.0 (chart 2.8.0), NodePort 30080 mapped to `localhost:18080` | k3s's built-in Traefik, on the load balancer's port 80, mapped to `localhost:18082` |
| Gateway | NGINX Gateway Fabric 2.8.0, with `extras/gateway-kind.yaml` (`hk-gateway`), NodePort 30081 mapped to `localhost:18081` | Traefik's `traefik-gateway`, turned on by `extras/traefik-gateway-provider.yaml` |
| Gateway API CRDs | v1.6.2, the version NGINX Gateway Fabric 2.8.0 is built against | v1.4.0, shipped with k3s |
| Rewriting for E5 | the `nginx.org/rewrites` annotation | a `stripPrefix` `Middleware`, created by `rewrite_args` in `lib.sh` |

The charts, the controller images and the CRD manifest are pinned, and checked against their digests or SHA-256.

E12 found that a rolling upgrade dropped a request now and then, because the app exits as soon as it gets SIGTERM (2.2), before the Service and the proxy stop sending it requests. The chart now has a `preStop` sleep of 5 seconds (#123). Without it, E12 failed 3 runs of 3; with it, it passed 3 of 3.

The NGINX Ingress Controller needs a host on each Ingress, and allows one Ingress per host, so each routing scenario gives each release its own host, and sends it as the `Host` header. `nginx.org/rewrites` works with the chart's path, which has no trailing slash (#123).

## Proposed layout

```
test/
  e2e/
    kind-config.yaml
    k3d-config.yaml
    extras/                  # per-cluster Middleware, Gateways, Traefik Gateway provider config (above)
    lib.sh                   # assert helpers: page_contains, wait_ready, http_status, dump_diagnostics
    run.sh                   # run.sh <kind|k3d> [scenario...]: create cluster, load image, run scenarios, tear down
    scenarios/
      e01-default.sh
      e02-page-details.sh
      ...
  image/
    run.sh                   # I1–I7
```

`Makefile` targets:

```make
test-image:   ## image tests (I1–I7)
e2e-kind:     ## build image, run e2e on kind
e2e-k3d:      ## build image, run e2e on k3d
e2e:          ## both
e2e-clean:    ## delete leftover hk-e2e clusters
```

I'd write the tests as plain Bash with a small assert library rather than adding a framework. The repo is already Makefile and shell, the checks are `curl` and `kubectl` calls, and contributors can read them without learning a new tool. Each scenario uses its own namespace, so they can run one after another on a single cluster without interfering. On failure, `dump_diagnostics` prints `kubectl get all,events`, pod logs and `describe` output for that namespace.

## CI

`.github/workflows/tests.yaml` (#98) runs on every PR into `main` and `release-*`, on pushes to those branches, and by hand. Its jobs are required checks in the ruleset:

| Job | Runner | Runs |
|---|---|---|
| `image-tests (amd64)` | `ubuntu-latest` | builds the image natively, then `test/image/run.sh` (I1–I7, I5a) and `test/proxy/run.sh` (P1–P3) |
| `image-tests (arm64)` | `ubuntu-24.04-arm` | the same, on a native arm64 runner |
| `e2e (kind, amd64)` | `ubuntu-latest` | runs `test/chart/run.sh` (C1–C17), builds a single-platform image, then `test/e2e/run.sh kind` with the default chart |
| `e2e (k3d, amd64)` | `ubuntu-latest` | the same on k3d |
| `e2e (kind, arm64)` | `ubuntu-24.04-arm` | the same on kind, on a native arm64 runner |
| `e2e (kind, amd64, Kubernetes 1.35)` | `ubuntu-latest` | E1, E6 and E7 on the oldest supported Kubernetes (E13) |
| `e2e (k3d, arm64)` | `ubuntu-24.04-arm` | the same on k3d, on a native arm64 runner |

Each job builds and tests its own architecture, with no QEMU. An earlier plan built a multi-arch image once and tested other platforms under emulation. Native runners test the real image, and avoid `kind load` failing on multi-platform images (#87). The arm64 e2e jobs came with 4.1 (#113), when the chart stopped pinning pods to amd64.

A failed scenario prints its diagnostics in the job log. A new push to a PR cancels that PR's older runs.

The tool versions (Node.js, Trivy, kind, k3d, Helm, kubectl) are set only in `test/ci/install-tools.sh`, each with a SHA-256 for amd64 and arm64. The scan workflow and the devcontainer (#99) use the same table. All actions are pinned to commit SHAs, and the workflow has `permissions: contents: read`.

Test containers run with `docker run --pull never` (#98). Otherwise a `docker run --platform` for a platform the local image doesn't have pulls the published image and replaces the local tag, and later tests check the wrong image.

## Running locally

Prerequisites: Docker, `kind`, `k3d`, `kubectl`, `helm`, and `cloud-provider-kind` for E8.

The devcontainer (#50) has all of these, `cloud-provider-kind` since #123, and runs Docker inside the container (docker-in-docker), so the targets run there with no access to the host's Docker. See [docs/development-environment.md](../../../docs/development-environment.md). To run them on the host instead, your user needs access to the Docker socket: add it to the `docker` group (`sudo usermod -aG docker $USER`, then log out and back in).

```sh
make test-image
make e2e-kind            # or: test/e2e/run.sh kind e06-ingress-prefix
make e2e-k3d
make e2e-clean
```

A full local run of both clusters takes about 5 minutes, most of it cluster creation.

`make cluster-kind` and `make cluster-k3d` (#127) start the same clusters and keep them, with the image loaded as the chart's default image, so the docs can be tried by hand. `make e2e-kind` and `make e2e-k3d` reuse a running one. `make cluster-clean` deletes them.

## Suggested order

Steps 1 and 3 were done together in #87 (2.5): the harness, the kind and k3d configs, and E1–E4, E7 and E11 on both clusters. Both clusters run Kubernetes 1.37, with node images pinned by digest in `run.sh`. The configs have no port mappings yet; step 2 adds them, on host ports other than 8080, which `make run` uses.

| Step | Work | Effort for an agent |
|---|---|---|
| 1 | `lib.sh`, `run.sh`, kind config, E1–E4, E7, E11 | **M** |
| 2 | NGINX Ingress Controller on kind, Traefik Middleware, E5, E6, E18 (proves #30/#38/#44 fixes and the value migration) | **M** |
| 3 | k3d config and running the same scenarios on k3d | **S** |
| 4 | Gateway API: CRDs, NGINX Gateway Fabric, Traefik Gateway provider, Gateways, E16, E17 | **M** |
| 5 | Image tests I1–I7 | **S** |
| 6 | CI workflow with the amd64 + arm64 matrix | **M** |
| 7 | E8–E10, E12–E14 | **M** |
| 8 | E15 docs-as-tests | **S–M** |

Steps 1–3 should land with the base image and chart changes, so each fix arrives with the test that proves it.
