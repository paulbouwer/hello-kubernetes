---
title: Testing
description: Image tests and e2e scenarios on kind (NGINX) and k3d (Traefik), Gateway API, the CI matrix and running locally.
type: plan
status: active
areas: [ci]
created: 2026-10-22
updated: 2026-10-28
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
2. **End-to-end (e2e) tests**: install the chart (and the plain manifest) on kind and k3d, then check behaviour over HTTP and through the Kubernetes API. Run on every PR.
3. **Manual release checks**: k3d on a real arm64 machine, a quick look in a browser, and the docs read through once.

## Image tests

These check the image itself and guard against the problems found in the review coming back.

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

## Proxy tests

`test/proxy/run.sh` (`make test-proxy`), added in #81, runs the image behind an NGINX container and checks that the page and every asset it links to load through the proxy. It covers deployments that don't use the chart, which the e2e scenarios don't reach.

| ID | Proxy | Prefixes | Guards against |
|---|---|---|---|
| P1 | Serves the app at `/hello/` and strips the path | none | #38 |
| P2 | Passes `/hello/` through | `RENDER_PATH_PREFIX` and `HANDLER_PATH_PREFIX` both `/hello` | the chart's recommended setup breaking |
| P3 | Serves the app at `/hello/` and strips the path | both only `/` | asset URLs becoming `//css/…` |

## End-to-end scenarios

Every scenario runs on both kind and k3d unless the "Clusters" column says otherwise. "Page" means the HTML returned by `GET /` (or `GET /<prefix>/`). The checks only use `kubectl`, `helm` and `curl`, so they behave the same locally and in CI.

| ID | Scenario | Setup | Pass criteria | Clusters | Covers |
|---|---|---|---|---|---|
| E1 | Default install | `helm install hello-world ./deploy/helm/hello-kubernetes -n hk-e1 --create-namespace --set service.type=ClusterIP --wait` | Deployment shows 2/2 ready. Through `kubectl port-forward svc/...`: page has `Hello world!`, the namespace `hk-e1`, a pod name and node name that match a real pod (`kubectl get pod -o jsonpath`), and the expected image tag | both | baseline |
| E2 | Page details are correct | same as E1 | The architecture shown matches the node's `kubernetes.io/arch` label | both | #40 |
| E3 | Custom message, escaped | `--set message='<b>Hi</b> & "you"'` | Install succeeds. Page has `&lt;b&gt;Hi&lt;/b&gt; &amp; &quot;you&quot;` and does **not** contain a raw `<b>Hi</b>` tag. **Expected to fail today:** `deployment.yaml` renders `value: "{{ .Values.message }}"`, so a message containing `"` produces invalid YAML. Fix with `{{ .Values.message \| quote }}` (same for `pathPrefix`) | both | message injection, chart quoting bug |
| E4 | Custom port | `--set deployment.container.port=9090` | Pods become ready (probes follow the port), page served through the service | both | #34 |
| E5 | Ingress with rewrite | Two releases (`hello-world`, `custom-message`) with `ingress.enabled=true`, `rewritePath=true`, prefixes `/app/hello-world` and `/app/custom`. Controller-specific annotations: `nginx.org/rewrites` on kind; a Traefik `stripPrefix` Middleware on k3d | `curl http://localhost:<port>/app/hello-world/` and `/app/custom/` each return their own page; CSS and image links resolve (200) | both | #31 docs |
| E6 | Ingress without rewrite (recommended) | One release with `ingress.enabled=true`, `ingress.className` for the cluster, `pathPrefix=/app/hello`, `rewritePath=false`, no annotations | Pods **ready** (no probe failures in `kubectl get events`); page, `css/main.css` and `images/kubernetes.png` all 200 under `/app/hello/` | both | #30, #44, #38 |
| E7 | Restricted Pod Security | Namespace labelled `pod-security.kubernetes.io/enforce=restricted`, chart installed with defaults | Install succeeds with no admission warnings; pods run with `runAsUser: 1000`; `kubectl exec ... -- id -u` prints `1000` | both | #35 |
| E8 | LoadBalancer service | `--set service.type=LoadBalancer`. kind: run `cloud-provider-kind`; k3d: built-in ServiceLB | Service gets an `EXTERNAL-IP` within 60s; page served through it | both | #1, #14 |
| E9 | Pods across nodes | `--set deployment.replicaCount=4` on a 1 control-plane + 2 worker cluster | Repeated requests through the service return at least 2 distinct pod names, and pods sit on at least 2 nodes | both | the demo's main point |
| E10 | Single-file manifest | `kubectl apply -f hello-kubernetes.yaml` (the rendered release asset), no Helm | Same checks as E1 | both | #29 |
| E11 | Clean uninstall | After E1: `helm uninstall hello-world -n hk-e1` then `kubectl delete ns hk-e1 --wait` | No Deployment, Service, ServiceAccount or pods left with the chart's labels | both | #28 |
| E12 | Rolling upgrade | Install with `message=v1`, then `helm upgrade --set message=v2 --wait` | All pods replaced, page shows `v2`, no downtime: a background `curl` loop during the upgrade sees no non-200 responses | kind | upgrades |
| E13 | Kubernetes version range | E1 + E6 + E7 on the oldest and newest Kubernetes versions the chart supports | Same pass criteria | kind (`kindest/node:<version>`) | API removals like #31 |
| E14 | arm64 nodes | E1 + E2 on an arm64 host | Architecture shown is `linux/arm64` | both, arm64 runner | #16 |
| E15 | Docs still work | Pull the shell commands from `README.md` quick start and `docs/deploy-with-ingress.md` (fenced blocks tagged for testing) and run them against the cluster | Each command exits 0 and the doc's described result is reached | kind | stops #31 recurring |
| E16 | HTTPRoute with rewrite | Two releases with `httpRoute.enabled=true`, `parentRefs` pointing at the test `Gateway`, `rewritePath=true`, prefixes `/app/hello-world` and `/app/custom` | Same as E5, through the Gateway. The rendered HTTPRoute has a `URLRewrite` filter and no controller-specific settings | both | Gateway API scope |
| E17 | HTTPRoute without rewrite | One release with `httpRoute.enabled=true`, `pathPrefix=/app/hello` | Same as E6, through the Gateway; the HTTPRoute is `Accepted` in its status | both | Gateway API scope |
| E18 | Old value names still work | Install with the old `ingress.configured=true`, `ingress.pathPrefix`, `ingress.rewritePath` and a hand-written Ingress | Same as E6 or E5, depending on `rewritePath` | kind | migration to top-level `pathPrefix`/`rewritePath` |

E15 needs a light convention in the docs, for example marking testable blocks as ```` ```sh e2e ````. It's the only scenario that changes the docs, so it can come last.

### Per-cluster extras

The chart now creates the Ingress and HTTPRoute itself, so the tests only supply what's specific to each controller. These double as the examples in `deploy.md` and `docs/deploy-with-ingress.md`:

- `test/e2e/extras/traefik-middleware.yaml`: a `stripPrefix` `Middleware` (`traefik.io/v1alpha1`) for E5 on k3d, referenced from `ingress.annotations` as `<ns>-<name>@kubernetescrd`.
- `test/e2e/extras/gateway-kind.yaml`: a `Gateway` using NGINX Gateway Fabric's `GatewayClass`, with `allowedRoutes` from all namespaces.
- `test/e2e/extras/gateway-k3d.yaml`: the same `Gateway` using Traefik's `GatewayClass`.

The NGINX rewrite for E5 on kind is an annotation (`nginx.org/rewrites`), passed through `ingress.annotations`, so it needs no extra file.

## Cluster setup

### kind

```yaml
# test/e2e/kind-config.yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
  - role: control-plane
    labels:
      ingress-ready: "true"
    extraPortMappings:
      - containerPort: 80
        hostPort: 8080
      - containerPort: 443
        hostPort: 8443
  - role: worker
  - role: worker
```

```sh
kind create cluster --name hk-e2e --config test/e2e/kind-config.yaml   # add --image kindest/node:<version> for E13
kind load docker-image paulbouwer/hello-kubernetes:<tag> --name hk-e2e
kubectl apply -f <Gateway API standard CRDs, pinned version>
helm install nginx-ingress <F5 NGINX Ingress Controller chart, pinned version> -n nginx-ingress --create-namespace   # hostPorts 80/443 on the ingress-ready node
helm install ngf <NGINX Gateway Fabric chart, pinned version> -n nginx-gateway --create-namespace
kubectl apply -f test/e2e/extras/gateway-kind.yaml
cloud-provider-kind &   # for E8, and to give the Gateway's service an address
```

The NGINX Ingress Controller takes ports 80/443 through kind's port mappings. NGINX Gateway Fabric provisions its own data-plane service per `Gateway`; reach it through the address `cloud-provider-kind` gives it, or a NodePort added to `extraPortMappings`. Check both charts' kind instructions when writing `run.sh`.

The community Ingress-NGINX controller would have been the obvious choice on kind, but it was retired in March 2026 (see `deploy.md`).

### k3d

```yaml
# test/e2e/k3d-config.yaml
apiVersion: k3d.io/v1alpha5
kind: Simple
metadata:
  name: hk-e2e
servers: 1
agents: 2
image: rancher/k3s:<pinned version>
ports:
  - port: 8081:80
    nodeFilters: [loadbalancer]
```

```sh
k3d cluster create --config test/e2e/k3d-config.yaml
k3d image import paulbouwer/hello-kubernetes:<tag> --cluster hk-e2e
kubectl apply -f <Gateway API standard CRDs, pinned version>
kubectl apply -f test/e2e/extras/traefik-gateway-provider.yaml   # HelmChartConfig enabling Traefik's kubernetesGateway provider
kubectl -n kube-system wait --for=condition=Available deploy/traefik --timeout=180s
kubectl apply -f test/e2e/extras/gateway-k3d.yaml
```

k3s ships Traefik with only the Ingress provider on. The Gateway API provider is enabled with a `HelmChartConfig` that sets `providers.kubernetesGateway.enabled: true`; check the exact values against the Traefik version in the pinned k3s.

Both clusters need the image tagged with a real version (never `latest`) so the chart's `imagePullPolicy: IfNotPresent` uses the loaded image instead of pulling from Docker Hub.

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

A new workflow, `.github/workflows/e2e.yaml`, on every pull request and on pushes to `main`:

1. **Build** the image once with Buildx for `linux/amd64` and `linux/arm64`, save it as a workflow artifact.
2. **Image tests** (I1–I7), with QEMU for the non-native platforms.
3. **E2E matrix**:

   | Cluster | Runner | Kubernetes |
   |---|---|---|
   | kind | `ubuntu-latest` (amd64) | oldest supported, newest |
   | kind | `ubuntu-24.04-arm` (arm64) | newest |
   | k3d | `ubuntu-latest` (amd64) | pinned k3s |
   | k3d | `ubuntu-24.04-arm` (arm64) | pinned k3s |

4. **On failure**, upload the diagnostics dump as an artifact.
5. Make the e2e jobs **required checks** before the publish workflow can run on a tag.

As in the rest of the workflows, pin every action to a commit SHA, set a least-privilege `permissions:` block (`contents: read` is enough here), and keep the kind, k3d, k3s, Gateway API CRD, NGINX Ingress Controller and NGINX Gateway Fabric versions current with Dependabot or Renovate (versions pinned inside scripts need Renovate's regex rules).

## Running locally

Prerequisites: Docker, `kind`, `k3d`, `kubectl`, `helm`, and `cloud-provider-kind` for E8.

The devcontainer (#50) has all of these except `cloud-provider-kind`, and runs Docker inside the container (docker-in-docker), so the targets run there with no access to the host's Docker. See [docs/development-environment.md](../../../docs/development-environment.md). To run them on the host instead, your user needs access to the Docker socket: add it to the `docker` group (`sudo usermod -aG docker $USER`, then log out and back in).

```sh
make test-image
make e2e-kind            # or: test/e2e/run.sh kind e06-ingress-prefix
make e2e-k3d
make e2e-clean
```

A full local run of both clusters should take roughly 10–15 minutes, most of it cluster creation.

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
